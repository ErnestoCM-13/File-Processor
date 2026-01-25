defmodule Benchmark do
  @moduledoc """
  Utility module to measure and compare execution performance.
  Evaluates the efficiency gain of parallel processing versus sequential processing.
  """

  # ----------------------------------------------------------------------
  # PUBLIC API
  # ----------------------------------------------------------------------

  @doc """
  Measures the execution performance of a given function.
  Uses `System.monotonic_time/1` and inspects all running processes for memory usage.

  ## Parameters
  - `function`: The function to be measured.

  ## Returns
  - `{benchmark_metrics, result_of_function}`

  ## Benchmark metrics map
  - `:time` - total execution time in seconds
  - `:memory_mb` - approximate memory usage in MB
  - `:processes` - number of processes used (extracted from `:processes_used` if present)
  """
  def measure(function) when is_function(function) do
    start_time = System.monotonic_time(:microsecond)

    start_memory = total_process_memory()

    funtion_results = function.()

    end_time = System.monotonic_time(:microsecond)

    end_memory = total_process_memory()

    memory_used_mb = Float.round((end_memory - start_memory) / 1_048_576, 2)

    total_time_seconds = (end_time - start_time) / 1_000_000

    processes_count = if is_map(funtion_results), do: Map.get(funtion_results, :processes_used, 1), else: 1

    benchmark_metrics = %{
      time: total_time_seconds,
      memory_mb: memory_used_mb,
      processes: processes_count
    }

    {benchmark_metrics, funtion_results}
  end

  @doc """
  Calculates performance improvement between sequential and parallel execution.

  ## Parameters
  - `sequential_metrics`: Benchmark metrics from sequential run.
  - `parallel_metrics`: Benchmark metrics from parallel run.

  ## Returns
  - Map with sequential time, parallel time, improvement factor, processes used, and max memory used.
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

  # ----------------------------------------------------------------------
  # HELPERS
  # ----------------------------------------------------------------------

  defp total_process_memory do
    Process.list()
    |> Enum.reduce(0, fn pid, acc ->
      acc + (Process.info(pid, :memory) |> elem(1))
    end)
  end
end
