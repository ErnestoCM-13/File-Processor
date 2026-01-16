defmodule FileProcessor.CsvProcessorTest do
  use ExUnit.Case

  test "processes valid CSV and returns correct core metrics" do
    {:ok, metrics} =
      FileProcessor.CsvProcessor.process("data/valid/ventas_enero.csv")

    assert metrics.processed_lines == 30
    assert metrics.unique_products > 0
    assert metrics.total_sales > 0
    assert metrics.errors_found == 0
  end

  test "processes corrupted CSV and reports parsing errors" do
    {:ok, metrics} =
      FileProcessor.CsvProcessor.process("data/error/ventas_corrupto.csv")

    assert metrics.processed_lines > 0
    assert metrics.errors_found > 0
    assert length(metrics.error_details) == metrics.errors_found
  end
end
