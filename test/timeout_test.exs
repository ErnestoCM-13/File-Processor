defmodule Parallel.TimeoutTest do
  use ExUnit.Case, async: true
  alias Parallel.Coordinator

  @doc """
  Tests the global timeout logic. If workers take longer than the
  specified :timeout, the coordinator should force-stop and return
  the current accumulated metrics.
  """
  test "coordinator triggers global timeout when processing takes too long" do
    parent = self()

    # Using a worker that never finishes
    config = %{
      worker_module: TestSupport.NeverEndingWorker,
      timeout: 100 # Very short timeout to trigger it fast
    }

    file_list = [{"heavy/file.csv", "heavy.csv"}]

    Coordinator.start_parallel_processing(file_list, parent, config)

    # Should receive :all_done due to global_timeout
    assert_receive {:all_done, _metrics}, 500

  end
end
