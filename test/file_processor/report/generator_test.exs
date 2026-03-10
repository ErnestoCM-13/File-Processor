defmodule FileProcessor.Report.GeneratorTest do
  use ExUnit.Case, async: true
  alias FileProcessor.Report.Generator
  alias FileProcessor.Core.Metrics

  # ----------------------------------------------------------------------
  # HELPERS
  # ----------------------------------------------------------------------

  defp build_metrics(overrides \\ %{}) do
    struct!(Metrics, Map.merge(%{
      csv: [],
      json: [],
      log: [],
      errors: []
    }, overrides))
  end

  # ----------------------------------------------------------------------
  # TESTS
  # ----------------------------------------------------------------------

  describe "build/3 - General behaviour" do
    test "generates report map successfully" do
      metrics = build_metrics()

      result = Generator.build(metrics, :sequential)

      assert is_map(result)
      assert Map.has_key?(result, :report)
    end

    test "generates a header with current path and processing mode" do
      metrics = build_metrics()

      result = Generator.build(metrics, :sequential)

      assert result.report =~ "PROCESSED FILES REPORT"
      assert result.report =~ "Process mode: Sequential"
      assert result.report =~ "Processed path: #{File.cwd!()}"
    end

    test "includes executive summary with correct success rate" do
      metrics = build_metrics(%{
        csv: [%{file: "test.csv", metrics: %{total_sales: 100, unique_products: 1, top_product: "A", top_category: "X", average_discount: 0, date_range: "2023", errors_found: 0}}],
        errors: [%{file: "bad.txt", reason: "invalid format"}]
      })

      result = Generator.build(metrics, :sequential)

      assert result.report =~ "EXECUTIVE SUMMARY"
      assert result.report =~ "Total files processed: 1"
      assert result.report =~ "CSV Files: 1"
      assert result.report =~ "JSON Files: 0"
      assert result.report =~ "LOG Files: 0"
      assert result.report =~ "Total error files: 1"
      assert result.report =~ "Success rate: 50.0%"
    end
  end

  describe "build/3 - Specific sections" do
    test "calculates and displays consolidated totals for CSV section" do
      metrics = build_metrics(%{
        csv: [
          %{file: "a.csv", metrics: %{total_sales: 100, unique_products: 1, top_product: "A", top_category: "X", average_discount: 0, date_range: "2023", errors_found: 0}},
          %{file: "b.csv", metrics: %{total_sales: 150, unique_products: 1, top_product: "B", top_category: "Y", average_discount: 0, date_range: "2023", errors_found: 0}}
        ]
      })

      result = Generator.build(metrics, :sequential)

      assert result.report =~ "CSV FILES METRICS"
      assert result.report =~ "a.csv"
      assert result.report =~ "CSV Consolidated totals:"
      assert result.report =~ "Total sales: $250"

      refute result.report =~ "JSON FILES METRICS"
      refute result.report =~ "LOG FILES METRICS"
    end

    test "includes performance section only in benchmark mode" do
      performance_data = %{
        sequential_time: 1.0,
        parallel_time: 0.5,
        improvement: 2.0,
        processes: 4,
        max_processes_used: 4,
        memory_max: 10.0
      }
      metrics = build_metrics(%{performance: performance_data})

      report_bench = Generator.build(metrics, :benchmark).report
      assert report_bench =~ "PERFORMANCE ANALYSIS"
      assert report_bench =~ "Improvement: 2.0 times faster"

      report_seq = Generator.build(metrics, :sequential).report
      refute report_seq =~ "PERFORMANCE ANALYSIS"
    end
  end

  describe "build/3 - Errors management" do
    test "groups fatal errors and internal parsing errors in the same section" do
      metrics = build_metrics(%{
        errors: [%{file: "system.err", reason: "Disk full"}],
        json: [%{
          file: "data.json",
          metrics: %{
            errors_found: 2,
            error_details: ["Line 1: invalid", "Line 5: missing"],
            total_users: 0, active_users: 0, active_percent: 0, avg_session_duration: 0, total_pages_visited: 0, top_5_actions: []
          }
        }]
      })

      result = Generator.build(metrics, :sequential)

      assert result.report =~ "ERRORS"
      assert result.report =~ "system.err: Disk full"
      assert result.report =~ "data.json: 2 invalid entries found"
      assert result.report =~ "Line 1: invalid"
    end

    test "does not show error section if no errors exist" do
      metrics = build_metrics()

      result = Generator.build(metrics, :sequential)

      refute result.report =~ "ERRORS"
    end
  end
end
