defmodule Parallel.Coordinator do
  @moduledoc """
  Coordinator for parallel file processing.
  This module is delegated by `FileProcessor`when the `:parallel` atom processing mode is detected.
  Acts as a supervisor-like process that:
  - Spawns one worker process per file.
  - Monitors each worker to detect crashes.
  - Collects processing results and errors.
  - Enforces a global timeout for the entire operation.
  - Sends the final accumulated metrics back to the parent process.
  """

  @default_timeout 10_000
  @default_max_workers 50

  # ----------------------------------------------------------------------
  # PUBLIC API
  # ----------------------------------------------------------------------

  @doc """
  Main entry point for parallel processing. Spawns the coordinator process.

  ## Parameters
  - `file_list`: List of files info (tuple) to be processed.
  - `parent_pid`: The PID of the process that will receive the final results.
  - `config`: Optional configuration map.
      - `:timeout`: Global timeout in milliseconds.
      - `:worker_module`: Module responsible for processing individual files
  """
  def start_parallel_processing(file_list, parent_pid, config \\ %{}) when is_list(file_list) do
    spawn(Parallel.Coordinator, :initialize_coordinator, [file_list, parent_pid, config])
  end

  # ----------------------------------------------------------------------
  # COORDINATOR INITIALIZATION
  # ----------------------------------------------------------------------

  @doc """
  Initializes the coordinator state, spawns workers for each file, and sets a global timeout.
  """
  def initialize_coordinator(file_list, parent_pid, config) do
    total_files = length(file_list)

    timeout_ms = Map.get(config, :timeout, @default_timeout)

    worker_module = Map.get(config, :worker_module, Parallel.Worker)

    max_workers = Map.get(config, :max_workers, @default_max_workers)

    coordinator_state = %{
      total_files: total_files,
      completed_files: 0,
      parent_process: parent_pid,
      active_workers: %{},
      pending_files: file_list,
      max_workers: max_workers,
      worker_module: worker_module
    }

    initial_metrics = FileProcessor.set_initial_metrics_map()

    updated_state = spawn_workers_process(coordinator_state)

    Process.send_after(self(), :global_timeout, timeout_ms)

    coordinator_loop(updated_state, initial_metrics)
  end

  # ----------------------------------------------------------------------
  # WORKER SPAWNING
  # ----------------------------------------------------------------------

  @doc false
  # Iterates through the file list to spawn a monitored worker for each one.
  # Returns the updated state with a map of PIDs and file info.
  defp spawn_workers_process(state) do
    current_active_workers_count = map_size(state.active_workers)
    available_workers_slots = state.max_workers - current_active_workers_count

    if available_workers_slots > 0 and Enum.any?(state.pending_files) do
      {files_to_process, remaining_files} = Enum.split(state.pending_files, available_workers_slots)

      new_workers =
        Enum.reduce(files_to_process, state.active_workers, fn file_info, acc ->
          {pid, _ref} = spawn_monitor(state.worker_module, :init, [file_info, self()])
          Map.put(acc, pid, file_info)
        end)

      %{state | active_workers: new_workers, pending_files: remaining_files}
    else
      state
    end
  end

  # ----------------------------------------------------------------------
  # MAIN COORDINATOR LOOP
  # ----------------------------------------------------------------------

  @doc false
  # Main message loop. Handles worker completion, process crashes, and timeouts.
  defp coordinator_loop(state, accumulated_metrics) do
    receive do
      # ----------------------------------------------------------------------
      # Worker completed successfully
      # ----------------------------------------------------------------------
      {:worker_done, worker_pid, file_info, result} ->
        new_completed_count = state.completed_files + 1

        updated_metrics = FileProcessor.update_metrics_map(
          accumulated_metrics,
          result
        )

        print_progress(file_info, new_completed_count, state.total_files)

        state
        |> remove_worker(worker_pid)
        |> spawn_workers_process()
        |> check_completition(new_completed_count, updated_metrics)

      # ----------------------------------------------------------------------
      # Worker crashed
      # ----------------------------------------------------------------------
      {:DOWN, _ref, :process, worker_pid, reason} ->
        if Map.has_key?(state.active_workers, worker_pid) do
          {_file_path, file_name} = Map.get(state.active_workers, worker_pid)

          new_completed_count = state.completed_files + 1

          error_result =
            {:error, file_name, "Worker crashed: #{reason}"}

          updated_metrics =
            FileProcessor.update_metrics_map(
              accumulated_metrics,
              error_result
            )

          IO.puts("Error: Worker for #{file_name} crashed")

          state
          |> remove_worker(worker_pid)
          |> spawn_workers_process()
          |> check_completition(new_completed_count, updated_metrics)
        else
          coordinator_loop(state, accumulated_metrics)
        end

      # ----------------------------------------------------------------------
      # Global timeout exceeded
      # ----------------------------------------------------------------------
      :global_timeout ->
        updated_metrics =
          state.active_workers
          |> Map.values()
          |> Enum.reduce(accumulated_metrics, fn {_file_path, file_name}, acc ->
            IO.puts("Error: Worker for #{file_name} take too long")

            FileProcessor.update_metrics_map(
              acc,
              {:error, file_name, "Timeout exceeded"}
            )
          end)

        final_metrics =
          Map.put(updated_metrics, :processes_used, state.total_files)

        send(state.parent_process, {:all_done, final_metrics})
    end
  end

  # ----------------------------------------------------------------------
  # COMPLETITION CHECK
  # ----------------------------------------------------------------------

  defp remove_worker(state, worker_pid) do
    %{state | active_workers: Map.delete(state.active_workers, worker_pid)}
  end

  @doc false
  # Checks if all files have been processed (successfully or with error).
  # Notifies the parent process or continues the loop.
  defp check_completition(state, completed_files, accumulated_metrics) do
    if completed_files == state.total_files do
      final_results =
        accumulated_metrics
        |> Map.put(:processes_used, state.total_files)
        |> Map.put(:max_workers, state.max_workers)

      send(state.parent_process, {:all_done, final_results})
    else
      coordinator_loop(
        %{state |
          completed_files: completed_files
        },
        accumulated_metrics
      )
    end
  end

  # ----------------------------------------------------------------------
  # PROGRESS OUTPUT
  # ----------------------------------------------------------------------

  @doc false
  # Prints the current progress to the console.
  defp print_progress({_file_path, file_name}, completed, total) do
    IO.puts("Processed #{file_name}. Progress: #{completed}/#{total}")
  end
end
