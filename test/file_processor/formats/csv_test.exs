defmodule FileProcessor.Formats.CsvTest do
  use ExUnit.Case, async: true

  alias FileProcessor.Formats.Csv

  @valid_csv "data/valid/ventas_enero.csv"
  @csv_with_line_errors "data/error/ventas_corrupto.csv"

  # ----------------------------------------------------------------------
  # TESTS
  # ----------------------------------------------------------------------

  describe "process/1" do
    test "processes a fully valid CSV correctly" do
      {:ok, metrics} = Csv.process(@valid_csv)

      assert metrics.total_sales == 24399.93
      assert metrics.unique_products == 15
      assert metrics.average_discount == 12.0
      assert metrics.top_product == "Cable HDMI (40 units)"
      assert metrics.top_category == "Computadoras ($10289.91)"
      assert metrics.date_range == "2024-01-02 to 2024-01-30"
      assert metrics.processed_lines == 30
      assert metrics.errors_found == 0
      assert metrics.error_details == []
    end

    test "processes CSV with line errors correctly" do
      {:ok, metrics} = Csv.process(@csv_with_line_errors)

      assert metrics.total_sales == 1927.95
      assert metrics.unique_products == 3
      assert metrics.average_discount == 10.0
      assert metrics.top_product == "Tablet Samsung (3 units)"
      assert metrics.top_category == "Tablets ($1619.97)"
      assert metrics.date_range == "2024-03-01 to 2024-03-05"
      assert metrics.processed_lines == 3
      assert metrics.errors_found == 8
      assert metrics.error_details == [
        "line 2: Invalid price",
        "line 3: Invalid quantity",
        "line 4: Invalid quantity",
        "line 5: Corrupt line (missing columns)",
        "line 6: Invalid price",
        "line 7: Discount out of range (0-100)",
        "line 8: Corrupt line (missing columns)",
        "line 11: Invalid date format"
        ]
    end
  end
end
