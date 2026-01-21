defmodule FileProcessor.LogProcessorTest do
  use ExUnit.Case

  setup do
    %{
      valid_log: "data/valid/aplicacion.log",
      error_log: "data/error/sistema_corrupto.log"
    }
  end

  describe "process/1 with valid files" do
    test "returns metrics with the exact expected values", %{valid_log: valid_log} do
      {:ok, metrics} = FileProcessor.LogProcessor.process(valid_log)

      assert metrics.total_entries == 71
      assert metrics.level_distribution == [
        "DEBUG: 14.1%",
        "ERROR: 11.3%",
        "INFO: 66.2%",
        "WARN: 8.5%"
      ]
      assert metrics.most_problematic_component == "Integration (2 errors)"
      assert metrics.frequent_error_pattern == "Total: $1,299.99, Cliente: 4521 (1 ocurrences)"
      assert metrics.peak_log_hour == "8:00"
      assert metrics.errors_found == 0
      assert metrics.error_details == []
    end
  end

  describe "process/1 with error files" do
    test "skip invalid LOG lines and collects their errors", %{error_log: error_log} do
      {:ok, metrics} = FileProcessor.LogProcessor.process(error_log)

      assert metrics.total_entries == 3
      assert metrics.level_distribution == [
        "ERROR: 33.3%",
        "FATAL: 33.3%",
        "INFO: 33.3%"
      ]
      assert metrics.most_problematic_component == "DB (1 errors)"
      assert metrics.frequent_error_pattern == "Connection lost (1 ocurrences)"
      assert metrics.peak_log_hour == "14:00"
      assert metrics.errors_found == 3
      assert metrics.error_details == [
        "Invalid log format: [DEBUG] [APP] Missing date and...",
        "Invalid log format: 02/28/2024 14:10:00 [WARN] [SY...",
        "Invalid log format: Esto es una línea de texto bas..."
      ]
    end
  end
end
