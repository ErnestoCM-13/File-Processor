defmodule FileProcessor.CsvProcessorTest do
  use ExUnit.Case

  setup do
    %{
      valid_csv: "data/valid/ventas_enero.csv",
      error_csv: "data/error/ventas_corrupto.csv"
    }
  end

  describe "process/1" do
    test "returns a two-element tuple with :ok and a map", %{valid_csv: valid_csv} do
      assert {:ok, metrics} = FileProcessor.CsvProcessor.process(valid_csv)
      assert is_map(metrics)
    end

    test "returns a map with expected keys", %{valid_csv: valid_csv} do
      {:ok, metrics} = FileProcessor.CsvProcessor.process(valid_csv)
      expected_keys = [
        :total_sales,
        :unique_products,
        :average_discount,
        :top_product,
        :top_category,
        :date_range,
        :processed_lines,
        :errors_found,
        :error_details
      ]

      assert Enum.sort(Map.keys(metrics)) == Enum.sort(expected_keys)
    end

    test "returns metrics with the correct data type", %{valid_csv: valid_csv} do
      {:ok, metrics} = FileProcessor.CsvProcessor.process(valid_csv)

      assert is_float(metrics.total_sales)
      assert is_integer(metrics.unique_products)
      assert is_float(metrics.average_discount)
      assert is_binary(metrics.top_product)
      assert is_binary(metrics.top_category)
      assert is_binary(metrics.date_range)
      assert is_integer(metrics.processed_lines)
      assert is_integer(metrics.errors_found)
      assert is_list(metrics.error_details)
    end
  end

  describe "process/1 with valid files" do
    test "returns metrics with the exact expected values", %{valid_csv: valid_csv} do
      {:ok, metrics} = FileProcessor.CsvProcessor.process(valid_csv)

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
  end

  describe "process/1 with error files" do
    test "skip invalid lines and collects their errors", %{error_csv: error_csv} do
      {:ok, metrics} = FileProcessor.CsvProcessor.process(error_csv)

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
