defmodule FileProcessorWeb.FileProcessorLiveTest do
  use FileProcessorWeb.ConnCase
  import Phoenix.LiveViewTest
  alias FileProcessor.ResultsCache
  alias FileProcessor.Core.Metrics

  @results_id "TEST-ID-123"

  defp build_safe_metrics(overrides) do
    %Metrics{
      csv: [],
      json: [],
      log: [],
      errors: [],
      performance: %{
        parallel_time: 0.1,
        sequential_time: 0.1,
        memory_max: 1,
        improvement: 1.0
      },
      executive_summary: %{
        successfully_processed_files: 0,
        total_files: 1,
        total_errors: 0,
        total_warnings: 0
      }
    }
    |> put_in([Access.key(:executive_summary)], Map.merge(%{
      successfully_processed_files: 0,
      total_files: 1,
      total_errors: 0,
      total_warnings: 0
    }, Map.get(overrides, :executive_summary, %{})))
    |> Map.merge(Map.delete(overrides, :executive_summary))
  end

  describe "Dashboard Integration" do
    test "full flow: from start to detailed report", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      metrics = build_safe_metrics(%{
        csv: [%{file: "data.csv", metrics: %{rows: 100}}],
        executive_summary: %{
          successfully_processed_files: 1,
          total_files: 1,
          total_errors: 0,
          total_warnings: 0
        }
      })

      ResultsCache.put_processment_results(@results_id, metrics)

      send(view.pid, %{event: "all_done", payload: %{results: metrics, results_id: @results_id}})

      render(view)
      assert render(view) =~ "data.csv"
    end

    test "error handling: toggle error details", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      error_id = "ID-ERROR"

      metrics = build_safe_metrics(%{
        errors: [%{file: "bad.json", reason: "Invalid syntax"}],
        executive_summary: %{
          successfully_processed_files: 0,
          total_files: 1,
          total_errors: 1,
          total_warnings: 0
        }
      })

      ResultsCache.put_processment_results(error_id, metrics)

      send(view.pid, %{event: "all_done", payload: %{results: metrics, results_id: error_id}})

      rendered = render(view)
      assert rendered =~ "bad.json"

      view
      |> element("button", "View Reason")
      |> render_click()

      assert render(view) =~ "Invalid syntax"
    end
  end
end
