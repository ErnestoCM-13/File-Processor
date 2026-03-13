defmodule FileProcessor.Execution.Notifier do
  @moduledoc """
  Centralizes the broadcasting of processing events to the UI.
  """
  alias FileProcessorWeb.Endpoint

  @topic "processor_updates"

  def broadcast_file_progress(mode, file_name, result_formated, current, total, topic \\ @topic) do
    status = derive_status(result_formated)

    Endpoint.broadcast(topic, "file_processed", %{
      mode: mode,
      name: file_name,
      status: status,
      current: current,
      total: total
    })
  end

  def broadcast_completition(final_results, topic \\ @topic) do
    FileProcessorWeb.Endpoint.broadcast(topic, "all_done", %{
      results: final_results
    })
  end

  defp derive_status({:ok, _type, _name, %{errors_found: error_lines}}) when error_lines > 0, do: :warning
  defp derive_status({:ok, _, _, _}), do: :ok
  defp derive_status({:error, _, _}), do: :error
end
