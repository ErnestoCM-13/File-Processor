defmodule Benchmark do
  @moduledoc """
  Utility module to measure and compare execution performance.
  Evaluates the efficiency gain of parallel processing versus sequential processing.
  """

  @doc """
  Measures the execution time of a given function using `monotonic_time`.

  ## Parameters
  - `function`: The function to be measured.

  ## Returns
  - `{benchmark_metrics_map, result_of_function}`
  """
  def measure(function) when is_function(function) do
    start_time = System.monotonic_time(:microsecond)
    start_memory = Enum.reduce(Process.list(), 0, fn process, acc ->
      acc + (Process.info(process, :memory) |> elem(1))
    end)

    result = function.()

    end_time = System.monotonic_time(:microsecond)
    end_memory = Enum.reduce(Process.list(), 0, fn process, acc ->
      acc + (Process.info(process, :memory) |> elem(1))
    end)

    memory_used_mb = Float.round((end_memory - start_memory) / 1_048_576, 2)
    time_sec = (end_time - start_time) / 1_000_000
    processes = if is_map(result), do: Map.get(result, :processes_used, 1), else: 1

    benchmark_metrics = %{
      time: time_sec,
      memory_mb: memory_used_mb,
      processes: processes
    }

    {benchmark_metrics, result}
  end

  @doc """
  Calculates the speed improvement and returns it.
  """
  def calculate_performance(sequential_metrics, parallel_metrics) do
    %{
      sequential_time: sequential_metrics.time,
      parallel_time: parallel_metrics.time,
      improvement: Float.round(sequential_metrics.time / parallel_metrics.time, 2),
      processes: parallel_metrics.processes,
      memory_max: parallel_metrics.memory_mb
    }
  end
end
