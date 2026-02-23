defmodule FileProcessor.IntegrationWorkflowTest do
  use ExUnit.Case, async: false

  @doc """
  Tests the complete workflow: Coordinator receives a file,
  spawns workers, and produces a final report.
  """
  test "full processing flow" do
    path = "test/fixtures/sample_data.csv"
    Parallel.Coordinator.start_parallel_processing([{path, "sample.csv"}], self())
    assert_receive {:all_done, _results}, 5000
  end
end
