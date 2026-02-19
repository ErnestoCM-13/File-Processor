defmodule FileProcessorWeb.MetricsController do
  use FileProcessorWeb, :controller

  def index(conn, _params) do
      results = get_session(conn, :results)

      if results do
        render(conn, :index, results: results)
      else
        conn
        |> redirect(to: ~p"/")
      end
    end
end
