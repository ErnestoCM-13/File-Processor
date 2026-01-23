defmodule Parallel.WorkerTest do
  use ExUnit.Case

  setup do
    %{
      coordinator: self(),
      file_path: "data/valid/ventas_enero.csv",
      results:
        {:ok, :csv, "ventas_enero.csv", %{
          average_discount: 12.0, date_range: "2024-01-02 to 2024-01-30",
          error_details: [],
          errors_found: 0,
          processed_lines: 30,
          top_category: "Computadoras ($10289.91)",
          top_product: "Cable HDMI (40 units)",
          total_sales: 24399.93,
          unique_products: 15
        }}
    }
  end

  test "init sends processed result to coordinator", %{coordinator: coordinator, file_path: file_path, results: results} do
    Parallel.Worker.init(file_path, coordinator)

    assert_receive {:worker_done, pid, file_path_received, results_received}
    assert pid == self()
    assert file_path_received == file_path
    assert results_received == results
  end
end
