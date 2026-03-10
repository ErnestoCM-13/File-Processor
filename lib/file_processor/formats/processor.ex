defmodule FileProcessor.Formats.Processor do
  @moduledoc """
  Behaviour implemented by all file format processors.

  Each supported file format (CSV, JSON, LOG, etc.) must provide a module
  that implements this behaviour. The processor module is responsible for
  reading, parsing the file and extracting the metrics.
  """

  @doc """
  Processes a file and returns the extracted metrics.

  ## Parameters
  - `file_path`:
      Path to the file to be processed.

  ## Returns
  - `{:ok, metrics}` when the file was successfully processed.
  - `{:error, reason}` when the file could not be processed.
  """
  @callback process(String.t()) :: {:ok, map()} | {:error, String.t()}
end
