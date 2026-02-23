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

  test "init sends processed result to coordinator" do
    coordinator_pid = self()
    path = "data/valid/ventas_enero.csv"
    Parallel.Worker.init(path, coordinator_pid)
    assert_receive {:worker_done, _pid, _info, _result}, 2000
  end
end
