defmodule BenchmarkTest do
  use ExUnit.Case

  describe "measure/1" do
    test "returns benchmark metrics and function result" do
      fun = fn -> 1 + 2 end
      {metrics, result} = Benchmark.measure(fun)

      assert result == 3
      assert is_map(metrics)
    end

    test "returns a map with expected keys" do
      fun = fn -> 1 + 2 end
      {metrics, _result} = Benchmark.measure(fun)

      assert Map.has_key?(metrics, :time)
      assert Map.has_key?(metrics, :memory_mb)
      assert Map.has_key?(metrics, :processes)
    end

    test "returns metrics with razonable values" do
      fun = fn -> 1 + 2 end
      {metrics, _result} = Benchmark.measure(fun)

      assert metrics.time >= 0
      assert is_float(metrics.memory_mb)
      assert metrics.processes >= 1
    end

    test "number of process used is read from result map if available" do
      fun = fn -> %{processes_used: 5, data: :ok} end
      {metrics, result} = Benchmark.measure(fun)

      assert result == %{processes_used: 5, data: :ok}
      assert metrics.processes == 5
    end
  end

  describe "calculate_performance/2" do
    test "calculates improvement and returns correct fields" do
      sequential = %{time: 10.0, memory_mb: 100, processes: 1}
      parallel = %{time: 2.0, memory_mb: 120, processes: 4}

      result = Benchmark.calculate_performance(sequential, parallel)

      assert result.sequential_time == 10.0
      assert result.parallel_time == 2.0
      assert result.improvement == 5.0
      assert result.processes == 4
      assert result.memory_max == 120
    end
  end
end
