defmodule FileProcessorTest do
  use ExUnit.Case, async: true

  # ----------------------------------------------------------------------
  # FAKES
  # ----------------------------------------------------------------------

  defmodule FakeNormalizer do
    def normalize_entry(:list, input), do: Enum.map(input, &({&1, Path.basename(&1)}))
  end

  defmodule FakeExecutor do
    def run(files, metrics, _config) do
      metrics
      |> Map.put(:processes_used, length(files))
      |> Map.put(:executive_summary, %{executed_by: "fake_executor"})
    end
  end

  defmodule FakeGenerator do
    def build(metrics, mode, _config) do
      files = metrics.processes_used
      trace = metrics.executive_summary.executed_by

      %{metrics |
        report: "Report for #{mode}. Files: #{files}. Trace: #{trace}"
      }
    end
  end

  # ----------------------------------------------------------------------
  # TESTS
  # ----------------------------------------------------------------------

  describe "process_files/4" do
    test "orchestrates the flow from normalization to report generation" do
      input = ["file1.csv", "file2.csv"]
      config = %{
        normalization_module: FakeNormalizer,
        sequential_module: FakeExecutor,
        generator_module: FakeGenerator
      }

      result = FileProcessor.process_files(:sequential, :list, input, config)

      assert result.report == "Report for sequential. Files: 2. Trace: fake_executor"
    end

    test "dispatches to the correct execution mode" do
      config = %{
        parallel_module: FakeExecutor,
        generator_module: FakeGenerator
      }

      result = FileProcessor.process_files(:parallel, :list, ["test.csv"], config)

      assert result.report =~ "Report for parallel"
    end
  end

  describe "Integration: process_files/4" do
    test "successfully processes real CSV files from a directory" do
      csv_file = ["data/valid/ventas_enero.csv"]

      result = FileProcessor.process_files(:sequential, :list, csv_file, %{})

      assert length(result.csv) == 1
      assert length(result.json) == 0
      assert length(result.log) == 0
      assert length(result.errors) == 0
      assert result.process_mode == "sequential"
      assert result.executive_summary == %{files_with_internal_errors: 0, success_rate_percentage: 100.0, successfully_processed_files: 1, total_files_attempted: 1}
      assert result.report =~ "PROCESSED FILES REPORT"
    end
  end
end
