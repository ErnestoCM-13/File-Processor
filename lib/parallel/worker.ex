defmodule Parallel.Worker do
  @moduledoc """
  Worker responsible for processing a single file in the parallel architecture.
  Each worker is spawned and monitored by `Parallel.FileProcessingCoordinator`.
  Upon finishing the processing, it reports the result back to the coordinator.
  """

  # ----------------------------------------------------------------------
  # PUBLIC API
  # ----------------------------------------------------------------------

  @doc """
  Initializes the worker process.

  ## Processing flow
  1. Processes the assigned file.
  2. Sends the result back to the coordinator.

  ## Parameters
  - `file_info`: Two element tuple with the name and path of the file to be processed.
  - `coordinator_pid`: PID of the `Parallel.Coordinator` process.
  """
  def init(file_info, coordinator_pid) do
    result = process_file(file_info)
    send(coordinator_pid, {:worker_done, self(), file_info, result})
  end

  # ----------------------------------------------------------------------
  # INTERNAL HELPERS
  # ----------------------------------------------------------------------

  @doc false
  # Delegates the actual file processing to the main FileProcessor module.
  # Returns either {:ok, metrics_map} or {:error, reason}
  defp process_file(file_info) do
    FileProcessor.process_single_file(file_info)
  end
end
