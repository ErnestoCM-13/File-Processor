defmodule Parallel.CoordinatorTest do
  use ExUnit.Case

  setup do
    %{
      valid_file: ["data/valid/ventas_febrero.csv"],
      multiple_files: [
        "data/valid/ventas_febrero.csv",
        "data/valid/usuarios.json",
        "data/valid/aplicacion.log"
      ],
      crash_config: %{worker_module: TestSupport.CrashingWorker},
      never_ending_config: %{worker_module: TestSupport.NeverEndingWorker, timeout: 50}
    }
  end

  describe "start_parallel_processing/3" do
    test "coordinator handles worker crash and collects their error", %{valid_file: valid_file, crash_config: config} do
      Parallel.Coordinator.start_parallel_processing(valid_file, self(), config)

      assert_receive {:all_done, results}, 1_000
      assert results.processes_used == 1
      assert length(results.errors) == 1
      assert hd(results.errors).reason == "Worker crashed: boom"
    end

    test "coordinator handles workers that exceed timeout and collects their error", %{valid_file: valid_file, never_ending_config: config} do
      Parallel.Coordinator.start_parallel_processing(valid_file, self(), config)

      assert_receive {:all_done, results}, 200
      assert results.processes_used == 1
      assert length(results.errors) == 1
      assert hd(results.errors).reason == "Timeout exceeded"
    end

    test "coordinator process valid files successfully", %{valid_file: valid_file} do
      Parallel.Coordinator.start_parallel_processing(valid_file, self(), %{})

      assert_receive {:all_done, results}, 1_000
      assert results.processes_used == 1
      assert results.errors == []
    end

    test "coordinator processes multiple files correctly", %{multiple_files: files} do
      Parallel.Coordinator.start_parallel_processing(files, self(), %{})

      assert_receive {:all_done, results}, 1_000
      assert results.processes_used == length(files)
      assert results.errors == []
    end
  end
end
