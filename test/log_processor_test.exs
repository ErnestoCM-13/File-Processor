defmodule FileProcessor.LogProcessorTest do
  use ExUnit.Case

  test "processes valid log file" do
    {:ok, metrics} =
      FileProcessor.LogProcessor.process("data/valid/aplicacion.log")

    assert metrics.total_entries > 0
    assert metrics.errors_found == 0
    assert metrics.peak_log_hour =~ ":00"
  end

  test "handles corrupted log entries" do
    {:ok, metrics} =
      FileProcessor.LogProcessor.process("data/error/sistema_corrupto.log")

    assert metrics.errors_found > 0
  end
end
