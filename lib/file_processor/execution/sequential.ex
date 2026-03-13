defmodule FileProcessor.Execution.Sequential do
  @moduledoc """
  Implements the sequential execution mode.

  Files are processed one by one in the current process, updating
  the metrics structure after each file is processed.
  """

  alias FileProcessor.Core.{Dispatcher, Metrics}
  alias FileProcessor.Execution.Notifier

  # ----------------------------------------------------------------------
  # EXECUTION STRATEGY
  # ----------------------------------------------------------------------

  @doc """
  Processes a list of files sequentially.

  Each file is dispatched to its corresponding processor based on
  the file extension, and the result is accumulated into the metrics
  structure.

  ## Parameters
  - `files`:
      List of `{file_path, file_name}` tuples.
  - `acc_metrics`:
      Metrics structure used to accumulate results.
  - `config`:
      Configuration used during execution.
  """
  def run(files, %Metrics{} = acc_metrics, config) do
    dispatcher = Map.get(config, :dispatcher_module, Dispatcher)


    total = Enum.count(files)

    # Cambiamos reduce por reduce_indexed (o usamos with_index)
    # para tener el contador del progreso
    files
    |> Enum.with_index(1)
    |> Enum.reduce(acc_metrics, fn {{path, name}, index}, current_acc_metrics ->
      extension = Path.extname(name)

      # 1. Procesamiento
      result_to_add = case dispatcher.get_processor(extension) do
        {:ok, processor} ->
          result = processor.process(path)
          format_result(name, result)

        {:error, reason} ->
          format_result(name, {:error, reason})
      end

      Notifier.broadcast_file_progress(:sequential, name, result_to_add, index, total)

      Metrics.add_result(current_acc_metrics, result_to_add)
    end)
  end

  # ----------------------------------------------------------------------
  # RESULT FORMATTING
  # ----------------------------------------------------------------------

  defp format_result(name, {:ok, data}), do: {:ok, detect_type(name), Path.basename(name), data}
  defp format_result(name, {:error, reason}), do: {:error, Path.basename(name), reason}

  defp detect_type(path) do
    path |> Path.extname() |> String.replace(".", "") |> String.to_atom()
  end
end
