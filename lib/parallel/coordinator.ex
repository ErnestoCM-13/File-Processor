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

  # ----------------------------------------------------------------------
  # PUBLIC API
  # ----------------------------------------------------------------------

  @doc """
  Main entry point for parallel processing. Spawns the coordinator process.

  ## Parameters
  - `file_paths`: List of file paths (strings) to be processed.
  - `parent_pid`: The PID of the process that will receive the final results.
  - `config`: Optional configuration map.
      - `:timeout`: Global timeout in milliseconds.
      - `:worker_module`: Module responsible for processing individual files
  """
  def start_parallel_processing(file_paths, parent_pid, config \\ %{}) when is_list(file_paths) do
    spawn(Parallel.Coordinator, :initialize_coordinator, [file_paths, parent_pid, config])
  end

  # ----------------------------------------------------------------------
  # COORDINATOR INITIALIZATION
  # ----------------------------------------------------------------------

  @doc """
  Initializes the coordinator state, spawns workers for each file, and sets a global timeout.
  """
  def initialize_coordinator(file_paths, parent_pid, config) do
    total_files = length(file_paths)

    timeout_ms = Map.get(config, :timeout, @default_timeout)

    worker_module = Map.get(config, :worker_module, Parallel.Worker)

    coordinator_state = %{
      total_files: total_files,
      completed_files: 0,
      parent_process: parent_pid,
      active_workers: %{},
      worker_module: worker_module
    }

    initial_metrics = FileProcessor.set_initial_metrics_map()

    updated_state = spawn_workers_process(file_paths, coordinator_state)

    Process.send_after(self(), :global_timeout, timeout_ms)

    coordinator_loop(updated_state, initial_metrics)
  end

  # ----------------------------------------------------------------------
  # WORKER SPAWNING
  # ----------------------------------------------------------------------

  @doc false
  # Iterates through the file list to spawn a monitored worker for each one.
  # Returns the updated state with a map of PIDs to file paths.
  defp spawn_workers_process(file_paths, state) do
    workers_map =
      Enum.reduce(file_paths, %{}, fn file_path, acc ->
        {pid, _monitor_ref} =
          spawn_monitor(
            state.worker_module,
            :init,
            [file_path, self()])

        Map.put(acc, pid, file_path)
      end)

    %{state | active_workers: workers_map}
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
      {:worker_done, worker_pid, file_path, result} ->
        new_completed_count = state.completed_files + 1

        updated_metrics = FileProcessor.update_metrics_map(
          accumulated_metrics,
          result
        )

        print_progress(file_path, new_completed_count, state.total_files)

        check_completition(worker_pid, state, new_completed_count, updated_metrics)

      # ----------------------------------------------------------------------
      # Worker crashed
      # ----------------------------------------------------------------------
      {:DOWN, _ref, :process, worker_pid, reason} ->
        if Map.has_key?(state.active_workers, worker_pid) do
          file_path = Map.get(state.active_workers, worker_pid)

          new_completed_count = state.completed_files + 1

          error_result =
            {:error, Path.basename(file_path), "Worker crashed: #{reason}"}

          updated_metrics =
            FileProcessor.update_metrics_map(
              accumulated_metrics,
              error_result
            )

          IO.puts("Error: Worker for #{Path.basename(file_path)} crashed")

          check_completition(worker_pid, state, new_completed_count, updated_metrics)
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
          |> Enum.reduce(accumulated_metrics, fn file_path, acc ->
            IO.puts("Error: Worker for #{Path.basename(file_path)} take too long")

            FileProcessor.update_metrics_map(
              acc,
              {:error, Path.basename(file_path),
              "Timeout exceeded"}
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

  @doc false
  # Checks if all files have been processed (successfully or with error).
  # Notifies the parent process or continues the loop.
  defp check_completition(worker_pid, state, completed_files, accumulated_metrics) do
    remaining_workers = Map.delete(state.active_workers, worker_pid)

    if completed_files == state.total_files do
      final_results =
        Map.put(accumulated_metrics, :processes_used, state.total_files)

      send(state.parent_process, {:all_done, final_results})
    else
      coordinator_loop(
        %{state |
          completed_files: completed_files,
          active_workers: remaining_workers
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
  defp print_progress(file_path, completed, total) do
    IO.puts("Processed #{Path.basename(file_path)}. Progress: #{completed}/#{total}")
  end
end
