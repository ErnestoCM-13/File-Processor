defmodule FileProcessorWeb.FileController do
  use FileProcessorWeb, :controller

  @doc """
  Main action to process uploaded files.
  Receives a list of files, execution mode, and runtime configuration.
  """
  def process(conn, %{"files" => files, "mode" => mode, "config" => config_params}) do
    # Convert string mode from frontend to atom (e.g., "parallel" -> :parallel)
    execution_mode = String.to_existing_atom(mode)

    # Parse runtime configuration from request parameters
    runtime_config = %{
      timeout: String.to_integer(config_params["timeout"] || "10000"),
      max_workers: String.to_integer(config_params["max_workers"] || "4")
    }

    # Execute the processing flow and get the final map with the :report key
    final_result = run_processing_flow(execution_mode, files, runtime_config)

    # Return the map as JSON for the frontend to store in page cache
    json(conn, final_result)
  end

  # Helper to orchestrate processing based on the selected mode
  defp run_processing_flow(:benchmark, files, config) do
    # Measure sequential execution
    {seq_m, _} = Benchmark.measure(fn ->
      FileProcessor.process_files(:sequential, :list, files, config)
    end)

    # Measure parallel execution and capture processing results
    {par_m, results} = Benchmark.measure(fn ->
      FileProcessor.process_files(:parallel, :list, files, config)
    end)

    # Calculate performance metrics
    performance = Benchmark.calculate_performance(seq_m, par_m)

    # Inject performance data and generate the final report string
    results
    |> Map.put(:performance, performance)
    |> FileProcessor.Report.generate({:benchmark, results}, config)
  end

  # Standard flow for sequential or parallel modes
  defp run_processing_flow(mode, files, config) do
    results = FileProcessor.process_files(mode, :list, files, config)
    FileProcessor.Report.generate({mode, results}, config)
  end
end
