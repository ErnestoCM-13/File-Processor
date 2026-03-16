defmodule FileProcessorWeb.DetailedReportComponentTest do
  use FileProcessorWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias FileProcessor.ResultsCache

  test "renders skeleton when no results are present" do
    html = render_component(FileProcessorWeb.DetailedReportComponent,
      id: "rep",
      results_id: nil,
      current_file_details_filter: "all",
      selected_file: nil,
      expanded_error_file: nil,
      current_error_details: nil
    )

    assert html =~ "animate-pulse"
  end

  test "correctly applies file type filters" do
    results = %{
      csv: [%{file: "a.csv", metrics: %{rows: 10}}],
      json: [%{file: "b.json", metrics: %{rows: 20}}]
    }
    ResultsCache.put_processment_results("FILTER-ID", results)

    html = render_component(FileProcessorWeb.DetailedReportComponent,
      id: "rep",
      results_id: "FILTER-ID",
      current_file_details_filter: "csv",
      selected_file: nil,
      expanded_error_file: nil,
      current_error_details: nil
    )

    assert html =~ "a.csv"
    refute html =~ "b.json"
  end
end
