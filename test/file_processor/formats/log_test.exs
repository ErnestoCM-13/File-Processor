defmodule FileProcessor.Formats.LogTest do
  use ExUnit.Case, async: true

  alias FileProcessor.Formats.Log

  @valid_log "data/valid/aplicacion.log"
  @log_with_errors "data/error/sistema_corrupto.log"
  @log_missing_file "data/error/missing.log"

  # ----------------------------------------------------------------------
  # TESTS
  # ----------------------------------------------------------------------

  describe "process/1" do
    test "processes a fully valid log correctly" do
      {:ok, metrics} = Log.process(@valid_log)

      assert metrics.total_entries == 71
      assert metrics.level_distribution == [
        "DEBUG: 14.1%",
        "ERROR: 11.3%",
        "INFO: 66.2%",
        "WARN: 8.5%"
      ] |> IO.inspect(label: "Esperado")
      assert metrics.most_problematic_component == "Integration (2 errors)"
      assert metrics.frequent_error_pattern == "1,247 eventos registrados (1 occurrences)"
      assert metrics.peak_log_hour == "8:00"
      assert metrics.errors_found == 0
      assert metrics.error_details == []
    end

    test "processes log with malformed lines correctly" do
      {:ok, metrics} = Log.process(@log_with_errors)

      assert metrics.total_entries == 3
      assert metrics.level_distribution == [
        "ERROR: 33.3%",
        "FATAL: 33.3%",
        "INFO: 33.3%"
      ]
      assert metrics.most_problematic_component == "DB (1 errors)"
      assert metrics.frequent_error_pattern == "Connection lost (1 occurrences)"
      assert metrics.peak_log_hour == "14:00"
      assert metrics.errors_found == 3
      assert metrics.error_details == [
        "Invalid log format: [DEBUG] [APP] Missing date and time at start",
        "Invalid log format: 02/28/2024 14:10:00 [WARN] [SYS] High memory usage",
        "Invalid log format: Esto es una línea de texto basura que no debería estar aquí"
      ]
    end

    test "returns error if log file not found" do
      assert {:error, msg} = Log.process(@log_missing_file)
      assert String.contains?(msg, "File not found")
    end
  end
end
