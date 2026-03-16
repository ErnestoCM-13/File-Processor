defmodule FileProcessor.Execution.Parallel do
  @moduledoc """
  Coordinator for parallel file processing.
  This module is delegated by `FileProcessor`when the `:parallel`
  execution mode is selected. Acts as a supervisor-like process that:
  - Spawns one worker process per file, up to a configurable max.
  - Monitors each worker to detect crashes.
  - Collects processing results and errors.
  - Enforces a global timeout for the entire operation.
  - Sends the final accumulated metrics back to the parent process.
  """

  alias FileProcessor.Core.{Dispatcher, Metrics}
  alias FileProcessor.Execution.Worker
  alias FileProcessor.Execution.Notifier

  @default_timeout 10_000
  @default_max_workers 50

  # ----------------------------------------------------------------------
  # PUBLIC API
  # ----------------------------------------------------------------------

  @doc """
  Main entry point for parallel processing. Spawns the coordinator process.

  ## Parameters
  - `file_list`: List of `{file_path, file_name}` tuples to process.
  - `parent_pid`: The PID of the process that will receive the final results.
  - `config`: Optional configuration map.
      - `:timeout`: Global timeout in milliseconds.
      - `:worker_module`: Module responsible for processing individual files
      - `:max_workers` - maximum concurrent workers.
  """
  def run(file_list, %Metrics{} = initial_metrics, config \\ %{}) do
    parent_pid = self()

    spawn(FileProcessor.Execution.Parallel, :initialize_coordinator, [file_list, initial_metrics, parent_pid, config])

    receive do
      {:all_done, final_metrics} -> final_metrics
    end
  end

  # ----------------------------------------------------------------------
  # COORDINATOR INITIALIZATION
  # ----------------------------------------------------------------------

  @doc """
  Initializes the coordinator state, spawns workers for each file, and sets a global timeout.
  """
  def initialize_coordinator(file_list, initial_metrics, parent_pid, config) do
    total_files = length(file_list)
    timeout_ms = Map.get(config, :timeout, @default_timeout)
    worker_module = Map.get(config, :worker_module, Worker)
    max_workers = Map.get(config, :max_workers, @default_max_workers)

    state = %{
      total_files: total_files,
      completed_files: 0,
      parent_process: parent_pid,
      active_workers: %{},
      pending_files: file_list,
      max_workers: max_workers,
      worker_module: worker_module
    }

    Process.send_after(self(), :global_timeout, timeout_ms)

    state
    |> spawn_workers()
    |> coordinator_loop(initial_metrics, config)
  end

  # ----------------------------------------------------------------------
  # WORKER SPAWNING
  # ----------------------------------------------------------------------

  @doc false
  # Iterates through the file list to spawn a monitored worker for each one.
  defp spawn_workers(state) do
    available_worker_slots = state.max_workers - map_size(state.active_workers)

    if available_worker_slots > 0 and Enum.any?(state.pending_files) do
      {files_to_process, remaining_files} = Enum.split(state.pending_files, available_worker_slots)

      new_workers =
        Enum.reduce(files_to_process, state.active_workers, fn {path, name}, acc_metrics ->
          extension = Path.extname(name)

          case Dispatcher.get_processor(extension) do
            {:ok, processor} ->
              {pid, _ref} = spawn_monitor(state.worker_module, :start_link, [{path, name}, processor, self()])
              Map.put(acc_metrics, pid, {path, name})

            {:error, reason} ->
               Metrics.add_result(acc_metrics, format_result(name, {:error, reason}))
          end
        end)

      %{state | active_workers: new_workers, pending_files: remaining_files}
    else
      state
    end
  end

  # ----------------------------------------------------------------------
  # COORDINATOR LOOP
  # ----------------------------------------------------------------------

  @doc false
  # Main message loop. Handles worker completion, crashes, and timeouts.
  defp coordinator_loop(state, accumulated_metrics, config) do
    receive do
      # ----------------------------------------------------------------------
      # Worker completed successfully
      # ----------------------------------------------------------------------
      {:worker_done, worker_pid, {_file_path, file_name}, result} ->
        new_completed_count = state.completed_files + 1
        result_formatted = format_result(file_name, result)
        updated_metrics = Metrics.add_result(accumulated_metrics, result_formatted)

        print_progress(file_name, new_completed_count, state.total_files)

        Notifier.broadcast_file_progress(:parallel, file_name, result_formatted, new_completed_count, state.total_files, config)

        state
        |> remove_worker(worker_pid)
        |> spawn_workers()
        |> check_completion(new_completed_count, updated_metrics, config)

      # ----------------------------------------------------------------------
      # Worker crashed
      # ----------------------------------------------------------------------
      {:DOWN, _ref, :process, worker_pid, reason} ->
        if Map.has_key?(state.active_workers, worker_pid) do
          {_file_path, file_name} = Map.get(state.active_workers, worker_pid)
          new_completed_count = state.completed_files + 1

          error_result = {:error, file_name, "Worker crashed: #{inspect(reason)}"}
          updated_metrics = Metrics.add_result(accumulated_metrics, error_result)

          IO.puts("Error: Worker for #{inspect(file_name)} crashed")

          Notifier.broadcast_file_progress(:parallel, file_name, error_result, new_completed_count, state.total_files, config)

          state
          |> remove_worker(worker_pid)
          |> spawn_workers()
          |> check_completion(new_completed_count, updated_metrics, config)
        else
          coordinator_loop(state, accumulated_metrics, config)
        end

      # ----------------------------------------------------------------------
      # Global timeout exceeded
      # ----------------------------------------------------------------------
      :global_timeout ->
        final_metrics =
          state.active_workers
          |> Map.values()
          |> Enum.reduce(accumulated_metrics, fn {_file_path, file_name}, acc ->
            IO.puts("Error: Worker for #{inspect(file_name)} take too long")
            new_completed_count = state.completed_files + 1
            error_result = {:error, file_name, "Timeout exceeded"}
            Notifier.broadcast_file_progress(:parallel, file_name, error_result, new_completed_count, state.total_files, config)
            Metrics.add_result(
              acc,
              error_result)
          end)
          |> Map.put(:processes_used, state.total_files)

        send(state.parent_process, {:all_done, final_metrics})
    end
  end

  # ----------------------------------------------------------------------
  # HELPERS
  # ----------------------------------------------------------------------

  defp remove_worker(state, worker_pid) do
    %{state | active_workers: Map.delete(state.active_workers, worker_pid)}
  end

  @doc false
  # Checks if all files have been processed (successfully or with error).
  # Notifies the parent process or continues the loop.
  defp check_completion(state, completed_files, accumulated_metrics, config) do
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
        accumulated_metrics, config)
    end
  end

  defp format_result(name, {:ok, data}), do: {:ok, detect_type(name), name, data}
  defp format_result(name, {:error, reason}), do: {:error, name, reason}

  defp detect_type(name) do
    name |> Path.extname() |> String.replace(".", "") |> String.to_atom()
  end

  # ----------------------------------------------------------------------
  # PROGRESS OUTPUT
  # ----------------------------------------------------------------------

  @doc false
  # Prints the current progress to the console.
  defp print_progress(file_name, completed, total) do
    IO.puts("Processed #{inspect(file_name)}. Progress: #{inspect(completed)}/#{inspect(total)}")
  end
end
