defmodule FileProcessor.Execution.BenchmarkTest do
  use ExUnit.Case, async: true
  alias FileProcessor.Execution.Benchmark
  alias FileProcessor.Core.Metrics

  # ----------------------------------------------------------------------
  # FAKES
  # ----------------------------------------------------------------------

  defmodule FakeSequential do
    def run(_files, _metrics, config) do
      # Simulamos una carga de trabajo controlada
      Process.sleep(config[:sleep_seq] || 10)

      %Metrics{
        processes_used: 1,
        max_workers: 1
      }
    end
  end

  defmodule FakeParallel do
    def run(_files, _metrics, config) do
      # Simulamos que el paralelo es más rápido
      Process.sleep(config[:sleep_par] || 5)

      %Metrics{
        processes_used: 4,
        max_workers: 4
      }
    end
  end

  # ----------------------------------------------------------------------
  # TESTS
  # ----------------------------------------------------------------------

  describe "run/3" do
    test "calculates performance improvement correctly between sequential and parallel" do
      files = [{"/path/to/file", "file.txt"}]
      initial_metrics = %Metrics{}

      config = %{
        sequential_module: FakeSequential,
        parallel_module: FakeParallel,
        sleep_seq: 100,
        sleep_par: 50
      }

      result = Benchmark.run(files, initial_metrics, config)

      # Verificamos comportamiento observable en el resultado final
      assert %Metrics{} = result
      perf = result.performance # Asumiendo que Metrics guarda esto aquí

      assert perf.processes == 4
      assert perf.max_processes_used == 4

      # El factor de mejora debería estar cerca de 2.0 (permitiendo una pequeña latencia de CPU)
      assert perf.improvement >= 1.5
      assert perf.sequential_time > perf.parallel_time
    end

    test "handles edge cases where parallel might be slower or equal" do
      config = %{
        sequential_module: FakeSequential,
        parallel_module: FakeParallel,
        sleep_seq: 10,
        sleep_par: 20
      }

      result = Benchmark.run([], %Metrics{}, config)

      perf = result.performance
      assert perf.improvement <= 1.0
    end
  end
end
