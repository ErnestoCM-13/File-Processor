defmodule FileProcessor.LogProcessorTest do
  use ExUnit.Case

  setup do
    %{
      valid_log: "data/valid/aplicacion.log",
      error_log: "data/error/sistema_corrupto.log"
    }
  end

  describe "process_log_files/1" do
    test "returns a two-element tuple with :ok and a map", %{valid_log: valid_log} do
      assert {:ok, metrics} = FileProcessor.LogProcessor.process_log_files(valid_log)
      assert is_map(metrics)
    end

    test "returns a map with expected keys", %{valid_log: valid_log} do
      {:ok, metrics} = FileProcessor.LogProcessor.process_log_files(valid_log)
      expected_keys = [
        :total_entries,
        :level_distribution,
        :most_problematic_component,
        :frequent_error_pattern,
        :peak_log_hour,
        :errors_found,
        :error_details
      ]

      assert Enum.sort(Map.keys(metrics)) == Enum.sort(expected_keys)
    end

    test "returns metrics with the correct data type", %{valid_log: valid_log} do
      {:ok, metrics} = FileProcessor.LogProcessor.process_log_files(valid_log)

      assert is_integer(metrics.total_entries)
      assert is_list(metrics.level_distribution)
      assert is_binary(metrics.most_problematic_component)
      assert is_binary(metrics.frequent_error_pattern)
      assert is_binary(metrics.peak_log_hour)
      assert is_integer(metrics.errors_found)
      assert is_list(metrics.error_details)
    end
  end

  describe "process_log_files/1 with valid files" do
    test "returns metrics with the exact expected values", %{valid_log: valid_log} do
      {:ok, metrics} = FileProcessor.LogProcessor.process_log_files(valid_log)

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
  end

  describe "process_log_files/1 with error files" do
    test "skip invalid LOG lines and collects their errors", %{error_log: error_log} do
      {:ok, metrics} = FileProcessor.LogProcessor.process_log_files(error_log)

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
  end
end
