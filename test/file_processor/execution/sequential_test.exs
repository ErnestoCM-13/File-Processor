defmodule FileProcessor.Execution.SequentialTest do
  use ExUnit.Case, async: true

  alias FileProcessor.Execution.Sequential
  alias FileProcessor.Core.Metrics

  # ---------------------------------------------------------------------------
  # FAKES
  # ---------------------------------------------------------------------------

  defmodule TestProcessorOk do
    @behaviour FileProcessor.Formats.Processor
    def process(_path), do: {:ok, %{some_metric: 1}}
  end

  defmodule TestProcessorError do
    @behaviour FileProcessor.Formats.Processor
    def process(_path), do: {:error, "failed"}
  end

  defmodule FakeDispatcher do
    def get_processor(".csv"), do: {:ok, TestProcessorOk}
    def get_processor(".json"), do: {:ok, TestProcessorError}
    def get_processor(_), do: {:error, "Unsupported file format"}
  end

  # ---------------------------------------------------------------------------
  # TESTS
  # ---------------------------------------------------------------------------

  describe "run/3" do
    test "processes files successfully" do
      files = [{"file1.csv", "file1.csv"}]
      metrics = Sequential.run(files, Metrics.new(), %{dispatcher_module: FakeDispatcher})

      assert length(metrics.csv) == 1
      assert length(metrics.log) == 0
      assert length(metrics.json) == 0
      assert length(metrics.errors) == 0
      assert Enum.at(metrics.csv, 0).metrics.some_metric == 1
    end

    test "handles processor errors" do
      files = [{"file2.json", "file2.json"}]
      metrics = Sequential.run(files, Metrics.new(), %{dispatcher_module: FakeDispatcher})

      assert length(metrics.csv) == 0
      assert length(metrics.log) == 0
      assert length(metrics.json) == 0
      assert length(metrics.errors) == 1
      assert Enum.at(metrics.errors, 0).reason == "failed"
    end

    test "handles unsupported extension" do
      files = [{"file3.xml", "file3.xml"}]

      metrics = Sequential.run(files, Metrics.new(), %{dispatcher_module: FakeDispatcher})

      assert length(metrics.csv) == 0
      assert length(metrics.log) == 0
      assert length(metrics.json) == 0
      assert length(metrics.errors) == 1
      assert Enum.at(metrics.errors, 0).reason == "Unsupported file format"
    end

    test "mix of successful, error, and unsupported files" do
      files = [
        {"good.csv", "good.csv"},
        {"fail.json", "fail.json"},
        {"bad.xml", "bad.xml"}
      ]

      metrics = Sequential.run(files, Metrics.new(), %{dispatcher_module: FakeDispatcher})

      assert length(metrics.csv) == 1
      assert length(metrics.log) == 0
      assert length(metrics.json) == 0
      assert length(metrics.errors) == 2
    end
  end
end
