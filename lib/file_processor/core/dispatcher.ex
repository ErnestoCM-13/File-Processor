defmodule FileProcessor.Core.Dispatcher do
  @moduledoc """
  Resolves the processor module responsible for handling a specific file type.

  This module maps file extensions to their corresponding processor modules.
  Each processor module is expected to implement the `Processor` behaviour
  and encapsulate the logic required to analyze and extract metrics from
  that file format.
  """

  alias FileProcessor.Formats.{Csv, Json, Log}

  # ----------------------------------------------------------------------
  # PUBLIC API
  # ----------------------------------------------------------------------

  @doc """
  Returns the processor module associated with a given file extension.
  The extension is normalized to lowercase before performing the lookup.

  ## Parameters
  - `extension`:
    A string representing the file extension (`.csv`, `.json`, `.log`).

  ## Returns
  - `{:ok, processor_module}` when the extension is supported.
  - `{:error, reason}` when the extension is not supported.
  """
  def get_processor(extension) do
    case String.downcase(extension) do
      ".csv"  -> {:ok, Csv}
      ".json" -> {:ok, Json}
      ".log"  -> {:ok, Log}
      _       -> {:error, "Unsupported file format: #{extension}"}
    end
  end
end
