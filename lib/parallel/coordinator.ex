defmodule Parallel.Coordinator do
  @moduledoc """
  Coordinator for parallel file processing.
  It is responable for:
  1. Managing the lifecycle of worker processes.
  2. Monitor workers using `spawn_monitor` to handle crashes.
  3. Accumulating metrics from all workers and returning the final result to the main process.
  """
  @default_timeout 10_000

  # --- PUBLIC API ---

  @doc """
  Main entry point for parallel processing. Spawns the coordinator process.

  ## Parameters
  - `files`: A list of strings containing the file paths to be processed.
  - `parent_pid`: The PID of the process that will receive the final results.
  - `config`: Optional map for configuration.
  """
  def start(files, parent_pid, config \\ %{}) when is_list(files) do
    spawn(Parallel.Coordinator, :init, [files, parent_pid, config])
  end

  @doc """
  Initializes the coordinator state, spawns workers for each file, and sets a global timeout.
  """
  def init(files, parent_pid, config) do
    total_files = length(files)
    timeout = Map.get(config, :timeout, @default_timeout)

    state = %{
      total: total_files,
      completed: 0,
      parent: parent_pid,
      workers: %{}
    }

    grouped_metrics = FileProcessor.set_initial_metrics_map()
    new_state = spawn_workers(files, state)

    Process.send_after(self(), :global_timeout, timeout)

    loop(new_state, grouped_metrics)
  end

  @doc false
  # Iterates through the file list to spawn a monitored worker for each one.
  # Returns the updated state with a map of PIDs to file paths.
  defp spawn_workers(files, state) do
    workers_map =
      Enum.reduce(files, %{}, fn file, acc ->
        # Usamos spawn_monitor para obtener el PID y la referencia de monitoreo
        {pid, _ref} = spawn_monitor(Parallel.Worker, :init, [file, self()])
        Map.put(acc, pid, file)
      end)

    %{state | workers: workers_map}
  end

  @doc false
  # Main message loop. Handles worker completion, process crashes, and timeouts.
  defp loop(state, grouped_metrics) do
    receive do
      # Case: Worker finished successfully
      {:worker_done, pid, file, result} ->
        new_completed = state.completed + 1
        new_grouped_metrics = FileProcessor.update_metrics_map(grouped_metrics, result)

        send_progress(file, new_completed, state.total)
        check_completition(pid, state, new_completed, new_grouped_metrics)

      # Case: Worker process died
      {:DOWN, _ref, :process, pid, reason} ->
        if Map.has_key?(state.workers, pid) do
          file = Map.get(state.workers, pid)
          new_completed = state.completed + 1

          error_result = {:error, Path.basename(file), "Worker crashed: #{reason}"}
          new_grouped_metrics = FileProcessor.update_metrics_map(grouped_metrics, error_result)

          IO.puts("Error: Worker for #{Path.basename(file)} crashed")
          check_completition(pid, state, new_completed, new_grouped_metrics)
        else
          loop(state, grouped_metrics)
        end

      # Case: The entire processing took too long
      :global_timeout ->
        new_grouped_metrics =
          state.workers
          |> Map.values()
          |> Enum.reduce(grouped_metrics, fn file, acc ->
            FileProcessor.update_metrics_map(acc, {:error, Path.basename(file), "Timeout exceeded"})
          end)

        send(state.parent, {:all_done, Map.put(new_grouped_metrics, :processes_used, state.total)})
    end
  end

  @doc false
  # Checks if all files have been processed (successfully or with error).
  # Notifies the parent process or continues the loop.
  defp check_completition(pid, state, completed, grouped_metrics) do
    new_workers = Map.delete(state.workers, pid)

    if completed == state.total do
      final_results = Map.put(grouped_metrics, :processes_used, state.total)
      send(state.parent, {:all_done, final_results})
    else
      loop(%{state | completed: completed, workers: new_workers}, grouped_metrics)
    end
  end

  @doc false
  # Prints the current progress to the console.
  defp send_progress(file, completed, total) do
    IO.puts("Processed #{Path.basename(file)}. Progress: #{completed}/#{total}")
  end
end
