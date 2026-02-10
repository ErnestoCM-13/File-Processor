defmodule FileProcessor do
  @moduledoc """
  Central orchestrator for the file processing system.

  It is responsible for coordinating the full lifecycle of file processing:
  - Finding files (from a `directory` or an explicit `lists`).
  - Determining how each file should be processed based on its extension.
  - Executing the processing flow according to the selected execution mode
    (`Sequential`, `Parallel`, or `Benchmark`).
  - Collecting metrics and errors produced during processing.
  - Sending them to the report generator.
  """

  # ----------------------------------------------------------------------
  # PUBLIC API
  # ----------------------------------------------------------------------

  @doc """
  Entry point of the file processing system.

  ## Parameters
  - `execution_mode`:
      An atom that determines how files are processed.
      Expected values: `:parallel`, `:sequential`, `:benchmark`.
  - `source_type`:
      An atom that indicates how file paths are provided.
      Expected values: `:directory` or `:list`.
  - `directory_path` or `path_list`:
      A directory path (string) when `source_type` is `:directory`,
      or a list of file paths (strings) when `source_type` is `:list`.
  - `runtime_config`:
      Configuration map used during processing and report generation.
  """
  def process_files(execution_mode, :directory, directory_path, runtime_config) when is_binary(directory_path) do
    case File.dir?(directory_path) do
      true ->
        path_list =
          directory_path
          |> File.ls!()
          |> Enum.map(&Path.join(directory_path, &1))

        process_files(execution_mode, :list, path_list, runtime_config)

      false -> {:error, "Directory not found"}
    end
  end

  def process_files(execution_mode, :list, path_list, runtime_config) when is_list(path_list) do
    case execution_mode do
      :sequential ->
        process_files_sequentially(path_list, runtime_config)

      :parallel ->
        process_files_in_parallel(path_list, runtime_config)

      :benchmark ->
        process_files_with_benchmark(path_list, runtime_config)
    end
  end

  # Error clauses for invalid data type
  def process_files(_execution_mode, :directory, _path), do: {:error, "Invalid argument, expected a string path"}
  def process_files(_execution_mode, :list, _path_list), do: {:error, "Invalid argument, expected a paths list"}

  # ----------------------------------------------------------------------
  # EXECUTION MODES
  # ----------------------------------------------------------------------

  defp process_files_sequentially(path_list, runtime_config) do
    results =
      set_initial_metrics_map()
      |> process_path_list(path_list)

    FileProcessor.Report.generate({:sequential, results}, runtime_config)
  end

  defp process_files_in_parallel(path_list, runtime_config) do
    Parallel.Coordinator.start_parallel_processing(path_list, self(), runtime_config)

    receive do
      {:all_done, results} -> FileProcessor.Report.generate({:parallel, results}, runtime_config)
    end
  end

  defp process_files_with_benchmark(path_list, runtime_config) do
    {sequential_metrics, _} =
      Benchmark.measure(fn ->
        set_initial_metrics_map()
        |> process_path_list(path_list)
      end)

    {parallel_metrics, parallel_results} =
      Benchmark.measure(fn ->
        Parallel.Coordinator.start_parallel_processing(path_list, self(), runtime_config)
        receive do: ({:all_done, results} -> results)
      end)

    performance = Benchmark.calculate_performance(sequential_metrics, parallel_metrics)

    final_results = Map.put(parallel_results, :performance, performance)

    FileProcessor.Report.generate({:benchmark, final_results}, runtime_config)
  end

  # ----------------------------------------------------------------------
  # SEQUENTIAL PROCESSING LOGIC
  # ----------------------------------------------------------------------

  @doc false
  # Recursive function to iterate through the path list for the sequential mode
  defp process_path_list(acumulated_metrics, []), do: acumulated_metrics

  defp process_path_list(acumulated_metrics, [current_path | remaining_paths]) do
    result = process_single_file(current_path)
    updated_metrics = update_metrics_map(acumulated_metrics, result)

    process_path_list(updated_metrics, remaining_paths)
  end

  # ----------------------------------------------------------------------
  # FILE PROCESSING LOGIC
  # ----------------------------------------------------------------------

  @doc """
  Validates file existence and dispatches it to the correct processor
  based on the file extension.
  """
  def process_single_file(file_path) when is_binary(file_path) do
    case File.exists?(file_path) do
      true ->
        file_path
        |> Path.extname()
        |> String.downcase()
        |> dispatch_file_by_extension(file_path)

      false ->
        {:error, Path.basename(file_path), "File not found"}
    end
  end

  # Error clause for invalid data type.
  def process_single_file(invalid_path), do: {:error, invalid_path, "Invalid argument, expected a string path"}

  # ----------------------------------------------------------------------
  # METRICS HANDLING
  # ----------------------------------------------------------------------

  @doc """
  Initializes the base structure used to accumulate processing results.
  Each key represents a supported file type, plus a shared error collection.
  """
  def set_initial_metrics_map do
    %{
      csv: [],
      json: [],
      log: [],
      errors: []
    }
  end

  @doc """
  Update the accumulated metrics structurewith the result of a processed file.
  """
  def update_metrics_map(acumulated_metrics, {:ok, file_type, file_name, metrics}) do
    Map.update!(acumulated_metrics, file_type, fn results ->
      [%{
        file: file_name,
        metrics: metrics,
        internal_errors: Map.get(metrics, :error_lines, [])
      } | results]
    end)
  end

  def update_metrics_map(acumulated_metrics, {:error, file_name, reason}) do
    Map.update!(acumulated_metrics, :errors, fn errors ->
      [%{
        file: file_name,
        reason: reason
      } | errors]
    end)
  end

  # ----------------------------------------------------------------------
  # FILE TYPE DISPATCHING LOGIC
  # ----------------------------------------------------------------------

  @doc false
  # These functions connect to specialized processing modules.
  defp dispatch_file_by_extension(".csv", file_path) do
    case FileProcessor.CsvProcessor.process_csv_file(file_path) do
      {:ok, metrics} ->
        {:ok, :csv, Path.basename(file_path), metrics}

      # {:error, reason} ->
        # {:error, Path.basename(file_path), reason}
    end
  end

  defp dispatch_file_by_extension(".json", file_path) do
    case FileProcessor.JsonProcessor.process_json_file(file_path) do
      {:ok, metrics} ->
        {:ok, :json, Path.basename(file_path), metrics}

      {:error, reason} ->
        {:error, Path.basename(file_path), reason}
    end
  end

  defp dispatch_file_by_extension(".log", file_path) do
    case FileProcessor.LogProcessor.process_log_files(file_path) do
      {:ok, metrics} ->
        {:ok, :log, Path.basename(file_path), metrics}

      {:error, reason} ->
        {:error, Path.basename(file_path), reason}
    end
  end

  # Error clause for unsupported file extensions.
  defp dispatch_file_by_extension(_extension, file_path) do
    {:error, Path.basename(file_path), "Unsupported file type. Expected files with extension .csv, .json or .log"}
  end
end
