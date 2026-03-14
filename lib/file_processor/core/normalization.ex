defmodule FileProcessor.Core.Normalization do
  @moduledoc """
  Responsible for normalizing different input sources into a standardized
  file representation.

  The system accepts multiple input formats (directory paths or explicit
  file lists). This module converts those inputs into a consistent list of:

      {file_path, file_name}

  which is the format expected by the processing pipeline.
  """

  # ----------------------------------------------------------------------
  # PUBLIC API
  # ----------------------------------------------------------------------

  @doc """
  Normalizes the provided input source into a list of `{file_path, file_name}` tuples.

  ## Parameters
  - `source_type`:
      Indicates how files are provided.
      Expected values:
      - `:directory`
      - `:list`
  - `input`:
      A directory path (string) when `source_type` is `:directory`,
      or a list containing file paths or `%Plug.Upload` structures
      when `source_type` is `:list`.

  ## Returns
  - A list of `{file_path, file_name}` tuples.
  - `{:error, reason}` when the directory does not exist.
  """
  def normalize_entry(:directory, directory_path) do
    if File.dir?(directory_path) do
      directory_path
      |> File.ls!()
      |> Enum.map(&{Path.join(directory_path, &1), &1})
    else
      {:error, "Directory not found"}
    end
  end

  def normalize_entry(:list, file_list) do
    Enum.map(file_list, &get_path_and_name/1)
  end

  # ----------------------------------------------------------------------
  # INTERNAL NORMALIZATION
  # ----------------------------------------------------------------------

  @doc false
  # Normalizes different input formats into a standard `{file_path, file_name}` tuple.
  defp get_path_and_name(%Plug.Upload{path: file_path, filename: file_name}),
    do: {file_path, file_name}

  defp get_path_and_name({file_path, file_name}) when is_binary(file_path) and is_binary(file_name),
    do: {file_path, file_name}

  defp get_path_and_name(file_path) when is_binary(file_path),
    do: {file_path, Path.basename(file_path)}

  # Error clause for invalid input format.
  defp get_path_and_name(invalid),
    do: {:error, "Unsupported file format #{invalid}, expected a string path, a two element tuple or a %Plug.Upload structure"}
end
