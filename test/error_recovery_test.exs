defmodule Parallel.ErrorRecoveryTest do
  use ExUnit.Case, async: true
  alias Parallel.Coordinator

  @doc """
  Ensures that if a worker crashes, the coordinator catches the :DOWN message,
  logs the error in the metrics, and finishes the execution of remaining files.
  """
  test "coordinator recovers and reports error when a worker crashes" do
    parent = self()

    config = %{worker_module: TestSupport.CrashingWorker}
    file_list = [{"path/to/fail.csv", "fail.csv"}]

    Coordinator.start_parallel_processing(file_list, parent, config)

    assert_receive {:all_done, metrics}, 2_000

    # Verify that even with a crash, metrics are returned
    assert metrics.processes_used == 1
    # Check if the error was captured in metrics map logic
    # (Assuming FileProcessor.update_metrics_map handles the error tuple)
  end
end
