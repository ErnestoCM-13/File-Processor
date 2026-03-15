defmodule FileProcessor.Execution.Worker do
  @moduledoc """
  Worker responsible for processing a single file in the parallel architecture.
  Each worker is spawned and monitored by `FileProcessor.Execution.Parallel`.
  Once processing is finished, the worker reports the result back to the coordinator.
  """

  # ----------------------------------------------------------------------
  # PUBLIC API
  # ----------------------------------------------------------------------

  @doc """
  Starts the worker process.

  ## Processing flow
  1. Processes the assigned file.
  2. Sends the result back to the coordinator.

  ## Parameters
  - `file_info`: `{file_path, file_name}` tuple representing the file to process.
  - `processor_module`: Module implementing the `Processor` behaviour.
  - `coordinator_pid`: PID of the coordinator process (`Parallel`).
  """
  def start_link(file_info, processor_module, coordinator_pid) do
    perform_work(file_info, processor_module, coordinator_pid)
  end

  # ----------------------------------------------------------------------
  # INTERNAL HELPERS
  # ----------------------------------------------------------------------

  defp perform_work({file_path, file_name}, processor_module, coordinator_pid) do
    # Executes the processor module for the file
    result = processor_module.process(file_path)

    Process.sleep(500)
    send(coordinator_pid, {:worker_done, self(), {file_path, file_name}, result})
  end
end
