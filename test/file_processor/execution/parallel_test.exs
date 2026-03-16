defmodule FileProcessor.Execution.ParallelTest do
  use ExUnit.Case, async: true

  alias FileProcessor.Execution.Parallel
  alias FileProcessor.Core.Metrics

  # ---------------------------------------------------------------------------
  # FAKES
  # ---------------------------------------------------------------------------

  defmodule TestWorkerSuccess do
    def start_link({_path, _name}, _processor, parent) do
      send(parent, {:worker_done, self(), {"dummy_path", "dummy.csv"}, {:ok, %{some_metric: 1}}})
      {:ok, self()}
    end
  end

  defmodule TestWorkerError do
    def start_link({_path, _name}, _processor, _parent) do
      exit(:boom)
    end
  end

  defmodule TestWorkerNeverEnding do
    def start_link({_path, _name}, _processor, _parent) do
      loop()
    end

    defp loop do
      Process.sleep(:infinity)
      loop()
    end
  end

  # ---------------------------------------------------------------------------
  # TESTS
  # ---------------------------------------------------------------------------

  describe "run/3" do
    test "all files processed successfully" do
      files = [{"file1.csv", "file1.csv"}, {"file2.csv", "file2.csv"}]

      metrics = Parallel.run(files, Metrics.new(), %{worker_module: TestWorkerSuccess})

      assert length(metrics.csv) == 2
      assert metrics.errors == []
    end

    test "worker returns error" do
      files = [{"fail.json", "fail.json"}]

      metrics = Parallel.run(files, Metrics.new(), %{worker_module: TestWorkerError})

      assert length(metrics.errors) == 1
      assert Enum.at(metrics.errors, 0).reason =~ "Worker crashed"
    end

    test "global timeout adds error for pending files" do
      files = [{"file_timeout.csv", "file_timeout.csv"}]

      metrics = Parallel.run(files, Metrics.new(), %{worker_module: TestWorkerNeverEnding, timeout: 10})

      assert length(metrics.errors) == 1
      assert Enum.at(metrics.errors, 0).reason =~ "Timeout exceeded"
    end
  end
end
