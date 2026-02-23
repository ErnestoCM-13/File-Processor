defmodule FileProcessor.ReportTest do
  use ExUnit.Case

  setup do
    %{
      config: %{report_name_label: "generated_for_tests"},

      csv_results: %{
        csv: [
          %{
            file: "ventas.csv",
            metrics: %{
              total_sales: 1000,
              unique_products: 3,
              top_product: "A",
              top_category: "Cat",
              average_discount: 10,
              date_range: "2024-01"
            }
          }
        ],
        json: [],
        log: [],
        errors: []
      },

      errors_results: %{
        csv: [
          %{
            file: "bad.csv",
            metrics: %{
              total_sales: 50,
              unique_products: 1,
              top_product: "B",
              top_category: "Dog",
              average_discount: 0,
              date_range: "2024-01",
              errors_found: 2,
              error_details: ["line 1 invalid", "line 3 invalid"]
            }
          }
        ],
        json: [],
        log: [],
        errors: [
          %{file: "fail.json", reason: "Parse error"}
        ]
      },

      benchmark_results: %{
        csv: [],
        json: [],
        log: [],
        errors: [],
        performance: %{
          sequential_time: 10.0,
          parallel_time: 2.0,
          improvement: 5.0,
          processes: 4,
          max_processes_used: 4, # Matches your lib/file_processor/report.ex:189
          memory_max: 128.0
        }
      }
    }
  end

  describe "generate/2" do
    @doc """
    Validates that the function returns a map containing the report string.
    Since the application code doesn't write to disk yet, we test the map content.
    """
    test "generates report map successfully", %{csv_results: results, config: config} do
      results_map = FileProcessor.Report.generate({:sequential, results}, config)

      assert is_map(results_map)
      assert Map.has_key?(results_map, :report)
      assert results_map.report =~ "PROCESSED FILES REPORT"
    end

    test "report content includes header and executive summary", %{csv_results: results, config: config} do
      results_map = FileProcessor.Report.generate({:sequential, results}, config)
      report_content = results_map.report

      assert report_content =~ "PROCESSED FILES REPORT"
      assert report_content =~ "EXECUTIVE SUMMARY"
      assert report_content =~ "Total files processed: 1"
    end

    test "report content includes CSV section when CSV entries exist", %{csv_results: results, config: config} do
      results_map = FileProcessor.Report.generate({:sequential, results}, config)
      report_content = results_map.report

      assert report_content =~ "CSV FILES METRICS"
      assert report_content =~ "ventas.csv"
      assert report_content =~ "CSV Consolidated totals"

      refute report_content =~ "JSON FILES METRICS"
      refute report_content =~ "LOG FILES METRICS"
    end
  end

  describe "generate/2 with error results" do
    test "report includes error section when errors exist", %{errors_results: results, config: config} do
      results_map = FileProcessor.Report.generate({:sequential, results}, config)
      report_content = results_map.report

      assert report_content =~ "ERRORS"
      assert report_content =~ "fail.json: Parse error"
      assert report_content =~ "bad.csv: 2 invalid entries found"
    end
  end

  describe "generate/2 with benchmark results" do
    test "report includes performance analysis in benchmark mode", %{benchmark_results: results, config: config} do
      results_map = FileProcessor.Report.generate({:benchmark, results}, config)
      report_content = results_map.report

      assert report_content =~ "PERFORMANCE ANALYSIS"
      assert report_content =~ "Sequential time: 10.0"
      assert report_content =~ "Max processes used simultaneously: 4"
    end
  end
end
