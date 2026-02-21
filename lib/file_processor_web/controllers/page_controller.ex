defmodule FileProcessorWeb.PageController do
  use FileProcessorWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def process(conn, %{"mode" => processing_mode_string, "files" => files} = params) do
    IO.inspect(params, label: "--- DATOS RECIBIDOS ---")
    # Converts processing mode strings into atoms
    processing_mode_atom = case processing_mode_string do
        "sequential" -> :sequential
        "parallel" -> :parallel
        "benchmark" -> :benchmark
        _ -> :sequential
      end

    # Prepares the config map
    processing_config = %{
      timeout: parse_int(params["timeout"]),
      max_workers: parse_int(params["workers"])
    }

    # Calls the file processor mock. Will be replaced with the real file processor logic
    results_map = FileProcessor.process_files(processing_mode_atom, :list, files, processing_config)

    # Generates an ID
    results_id = :crypto.strong_rand_bytes(16) |> Base.encode16()

    # Stores the results and id in the server memory
    FileProcessor.ResultsCache.put_processment_results(results_id, results_map)

    # Saves in session and redirects to the metrics page
    conn
    |> put_session(:results_id, results_id)
    |> redirect(to: ~p"/metrics")
  end

  # Parse helpers
  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)
  defp parse_int(val), do: val
end
