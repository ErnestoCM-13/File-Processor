defmodule FileProcessor.ReportTest do
  use ExUnit.Case

  setup do
    on_exit(fn ->
      "output/*generated_for_tests*"
      |> Path.wildcard()
      |> Enum.each(&File.rm!/1)
    end)

    %{
      config: %{report_name_label: "generated_for_tests"},
      report_path: "output/final_report_sequential_generated_for_tests.txt",
      benchmark_report_path: "output/final_report_benchmark_generated_for_tests.txt",
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
          improvement: 5,
          processes: 4,
          memory_max: 128
        }
      }
    }
  end

  describe "generate/2" do
    test "generates report file successfully", %{csv_results: results, config: config, report_path: report_path} do
      assert {:ok, message} = FileProcessor.Report.generate({:sequential, results}, config)
      assert message == "Report generated successfully: output/final_report_sequential_generated_for_tests.txt"
      assert File.exists?(report_path)
      assert report_path |> Path.basename() |> String.contains?("generated_for_tests")
    end

    test "report includes header and executive summary", %{csv_results: results, config: config, report_path: report_path} do
      FileProcessor.Report.generate({:sequential, results}, config)
      report_content = File.read!(report_path)

      assert report_content =~ "PROCESSED FILES REPORT"
      assert report_content =~ "EXECUTIVE SUMMARY"
      assert report_content =~ "Total files processed: 1"
      assert report_content =~ "Success rate: 100.0%"
    end

    test "report includes CSV section when CSV entries exist", %{csv_results: results, config: config, report_path: report_path} do
      FileProcessor.Report.generate({:sequential, results}, config)
      report_content = File.read!(report_path)

      assert report_content =~ "CSV FILES METRICS"
      assert report_content =~ "[File: ventas.csv]"
      assert report_content =~ "CSV Consolidated totals"
      refute report_content =~ "ERRORS"
      refute report_content =~ "JSON FILES METRICS"
      refute report_content =~ "LOG FILES METRICS"
    end
  end

  describe "generate/2 with error results" do
    test "report includes error section when errors exist", %{errors_results: results, config: config, report_path: report_path} do
      FileProcessor.Report.generate({:sequential, results}, config)
      report_content = File.read!(report_path)

      assert report_content =~ "ERRORS"
      assert report_content =~ "fail.json: Parse error"
      assert report_content =~ "bad.csv: 2 invalid entries found"
    end
  end

  describe "generate/2 with benchmark results" do
    test "report includes performance analysis in benchmark mode", %{benchmark_results: results, config: config, benchmark_report_path: report_path} do
      FileProcessor.Report.generate({:benchmark, results}, config)
      report_content = File.read!(report_path)

      assert report_content =~ "PERFORMANCE ANALYSIS"
      assert report_content =~ "Sequential time: 10.0"
    end
  end
end
