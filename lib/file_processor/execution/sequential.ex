defmodule FileProcessor.Execution.Sequential do
  @moduledoc """
  Implements the sequential execution mode.

  Files are processed one by one in the current process, updating
  the metrics structure after each file is processed.
  """

  alias FileProcessor.Core.{Dispatcher, Metrics}

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

    Enum.reduce(files, acc_metrics, fn {path, name}, current_acc_metrics ->
      extension = Path.extname(name)
      case dispatcher.get_processor(extension) do
        {:ok, processor} ->
          result = processor.process(path)
          Metrics.add_result(current_acc_metrics, format_result(name, result))

        {:error, reason} ->
           Metrics.add_result(current_acc_metrics, format_result(name, {:error, reason}))
      end
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
