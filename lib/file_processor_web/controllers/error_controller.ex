defmodule FileProcessorWeb.ErrorController do
  use FileProcessorWeb, :controller

  def index(conn, _params) do
    results_id = get_session(conn, :results_id)

    case FileProcessor.ResultsCache.get_processment_results(results_id) do
      nil ->
        conn |> put_flash(:error, "Session expired") |> redirect(to: ~p"/")
      results ->
        critical_errors = Enum.map(results.errors, fn err ->
          %{type: :critical, file: err.file, msg: err.reason}
        end)

        warning_errors =
          (results.csv ++ results.json ++ results.log)
          |> Enum.filter(fn item -> item.metrics.errors_found > 0 end)
          |> Enum.map(fn item ->
            %{type: :warning, file: item.file, details: item.metrics.error_details}
          end)

        all_errors = critical_errors ++ warning_errors

        # Counts for the error summary section
        counts = %{
          total: Enum.count(all_errors),
          critical: Enum.count(critical_errors),
          invalid: Enum.count(warning_errors)
        }

        render(conn, :index, errors: all_errors, counts: counts)
    end
  end
end
