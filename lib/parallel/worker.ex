defmodule Parallel.Worker do
  @moduledoc """
  Specific unit of work in the parallel architecture.
  Each worker is responsible for processing a single file using the `FileProcessor` logic.
  """

  @doc """
  Initializes the worker, triggers the processing logic, and sends the result back to the coordinator.

  ## Parameters
  - `file_path`: String path of the file to be processed.
  - `coordinator_pid`: PID of the `Parallel.Coordinator` process.
  """
  def init(file_path, coordinator_pid) do
    result = process_file(file_path)
    send(coordinator_pid, {:worker_done, self(), file_path, result})
  end

  @doc false
  # Delegates the actual file processing to the main FileProcessor module.
  defp process_file(file_path) do
    FileProcessor.process_path(file_path)
  end
end
