defmodule FileProcessorTest do
  use ExUnit.Case

  setup do
    %{
      valid_files: [
        "data/valid/ventas_enero.csv",
        "data/valid/usuarios.json",
        "data/valid/aplicacion.log"
      ],
      config: %{report_name_label: "generated_for_tests"}
    }
  end

  @doc """
  Tests sequential processing.
  Updated to match the map return value instead of {:ok, message}.
  """
  test "process_files sequential processing completes successfully", %{valid_files: valid_files, config: config} do
    # FIX: Remove {:ok, message} as the function returns the results map directly
    results = FileProcessor.process_files(:sequential, :list, valid_files, config)

    assert is_map(results)
    assert results.process_mode == :sequential
    assert results.executive_summary.success_rate_percentage == 100
    assert results.executive_summary.successfully_processed_files == 3
  end

  @doc """
  Tests parallel processing.
  Ensures the results map contains the parallel specific metrics.
  """
  test "process_files parallel processing completes successfully", %{valid_files: valid_files, config: config} do
    # FIX: Match against the map return value
    results = FileProcessor.process_files(:parallel, :list, valid_files, config)

    assert is_map(results)
    assert results.process_mode == :parallel
    assert results.processes_used == 3
    assert results.executive_summary.success_rate_percentage == 100
  end

  @doc """
  Tests benchmark mode.
  Checks that the :performance map is present in the return value.
  """
  test "process_files benchmark mode processing completes successfully", %{valid_files: valid_files, config: config} do
    results = FileProcessor.process_files(:benchmark, :list, valid_files, config)

    assert is_map(results)
    assert results.process_mode == :benchmark
    # Verify performance keys (adjusting to your implementation's keys)
    assert Map.has_key?(results, :performance)
    assert results.performance.processes == 3
  end

  @doc """
  Tests error handling for non-existent paths.
  Ensures the error reason matches the internal logic.
  """
  test "process_path handles non existent file paths" do
    invalid_path = "non_existent_folder"

    # Adjust this based on your actual return for invalid paths
    # If it returns a map with errors, use:
    results = FileProcessor.process_files(:sequential, :directory, invalid_path, %{})
    assert {:error, reason} = results
    assert reason =~ "not found"
  end
end
