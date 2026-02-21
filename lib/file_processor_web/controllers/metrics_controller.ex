defmodule FileProcessorWeb.MetricsController do
  use FileProcessorWeb, :controller

  def index(conn, _params) do
      results_id = get_session(conn, :results_id)

      case FileProcessor.ResultsCache.get_processment_results(results_id) do
        nil ->
          conn |> put_flash(:error, "Session expired") |> redirect(to: ~p"/")
        results ->
          render(conn, :index, results: results)
      end
    end
end
