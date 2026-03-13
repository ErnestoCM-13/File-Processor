defmodule FileProcessor.Execution.Benchmark do
  @moduledoc """
  Utility module to measure and compare execution performance.
  Evaluates the efficiency gain of parallel processing versus sequential processing.
  """

  alias FileProcessor.Core.Metrics
  alias FileProcessor.Execution.{Sequential, Parallel}

  # ----------------------------------------------------------------------
  # PUBLIC API
  # ----------------------------------------------------------------------

  @doc """
  Executes both sequential and parallel runs and compares their performance.

  ## Parameters
  - `files`: List of `{file_path, file_name}` tuples.
  - `initial_acc`: Initial metrics structure (ignored, used for type consistency).
  - `config`: Runtime configuration map.

  ## Returns
  - Metrics structure with performance data included.
  """
  def run(files, %Metrics{} = _initial_acc, config) do
    sequential = Map.get(config, :sequential_module, Sequential)
    parallel = Map.get(config, :parallel_module, Parallel)

    # Sequential benchmark
    task_seq = Task.async(fn ->
      measure(fn -> sequential.run(files, Metrics.new(), config) end)
    end)

    # Parallel benchmark
    task_par = Task.async(fn ->
      measure(fn -> parallel.run(files, Metrics.new(), config) end)
    end)

    {seq_bench, _seq_results} = Task.await(task_seq, :infinity)
    {par_bench, par_results} = Task.await(task_par, :infinity)

    performance_data = calculate_performance(seq_bench, par_bench)
    Metrics.add_performance_data(par_results, performance_data)
  end

  @doc """
  Measures execution time and approximate memory usage for a given function.

  ## Parameters
  - `function`: Function to be measured.

  ## Returns
  - `{benchmark_metrics, result_of_function}`

  ## Benchmark metrics map
  - `:time` - total execution time in seconds
  - `:memory_mb` - approximate memory usage in MB
  - `:processes` - number of processes used
  - `:max_processes_used` - maximum number of processes used at the same time
  """
  def measure(function) when is_function(function) do
    start_time = System.monotonic_time(:microsecond)
    start_memory = get_process_memory()

    function_results = function.()

    end_time = System.monotonic_time(:microsecond)
    end_memory = get_process_memory()

    memory_used_mb = max(0.0, Float.round((end_memory - start_memory) / 1_048_576, 4))
    total_time_seconds = (end_time - start_time) / 1_000_000

    {processes_total, max_processes_used} =
      if is_map(function_results) do
        processes_used = Map.get(function_results, :processes_used, 1)
        max_workers = Map.get(function_results, :max_workers, 1)
        {processes_used, min(processes_used, max_workers)}
      else
        {1, 1}
      end

    benchmark_metrics = %{
      time: total_time_seconds,
      memory_mb: memory_used_mb,
      processes: processes_total,
      max_processes_used: max_processes_used
    }

    {benchmark_metrics, function_results}
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
    improvement =
      if parallel_metrics.time > 0 do
        Float.round(sequential_metrics.time / parallel_metrics.time, 2)
      else
        0
      end

    %{
      sequential_time: sequential_metrics.time,
      parallel_time: parallel_metrics.time,
      improvement: improvement,
      max_processes_used: parallel_metrics.max_processes_used,
      processes: parallel_metrics.processes,
      memory_max: parallel_metrics.memory_mb
    }
  end

  # ----------------------------------------------------------------------
  # HELPERS
  # ----------------------------------------------------------------------

  defp get_process_memory do
    Process.list()
    |> Enum.reduce(0, fn pid, acc ->
      case Process.info(pid, :memory) do
        {_key, memory} -> acc + memory
        nil -> acc
      end
    end)
  end
end
