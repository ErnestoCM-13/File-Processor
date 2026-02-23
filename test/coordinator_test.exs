defmodule Parallel.CoordinatorTest do
  use ExUnit.Case

  @doc """
  Sets up the test data.
  Note: File list must be a list of tuples {path, name} to match
  the Coordinator's internal expectations.
  """
  setup do
    %{
      # Corrected to tuples: {path, name}
      valid_file: [{"data/valid/ventas_febrero.csv", "ventas_febrero.csv"}],
      multiple_files: [
        {"data/valid/ventas_febrero.csv", "ventas_febrero.csv"},
        {"data/valid/usuarios.json", "usuarios.json"},
        {"data/valid/aplicacion.log", "aplicacion.log"}
      ],
      # Ensure these modules exist in your test/support folder
      crash_config: %{worker_module: TestSupport.CrashingWorker},
      never_ending_config: %{worker_module: TestSupport.NeverEndingWorker, timeout: 50}
    }
  end

  describe "start_parallel_processing/3" do
    @tag :integration
    test "coordinator handles worker crash and collects their error", %{valid_file: valid_file, crash_config: config} do
      Parallel.Coordinator.start_parallel_processing(valid_file, self(), config)

      # We wait for the :all_done message sent by the coordinator
      assert_receive {:all_done, results}, 1_000
      assert results.processes_used == 1

      # Based on your Coordinator code, errors are part of the metrics map
      # Adjust the assertion based on how update_metrics_map stores them
      assert Map.has_key?(results, :errors)
    end

    test "coordinator handles workers that exceed timeout and collects their error", %{valid_file: valid_file, never_ending_config: config} do
      Parallel.Coordinator.start_parallel_processing(valid_file, self(), config)

      # The global_timeout in your code sends :all_done
      assert_receive {:all_done, results}, 500
      assert results.processes_used == 1
    end

    test "coordinator processes valid files successfully", %{valid_file: valid_file} do
      Parallel.Coordinator.start_parallel_processing(valid_file, self(), %{})

      assert_receive {:all_done, results}, 1_000
      assert results.processes_used == 1
    end

    test "coordinator processes multiple files correctly", %{multiple_files: files} do
      Parallel.Coordinator.start_parallel_processing(files, self(), %{})

      assert_receive {:all_done, results}, 2_000
      assert results.processes_used == length(files)
    end
  end
end
