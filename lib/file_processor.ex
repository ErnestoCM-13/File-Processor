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
  - `directory_path` or `file_list`:
      A directory path (string) when `source_type` is `:directory`,
      or a list of file paths (strings) or a %Plug.Upload structure list
      when `source_type` is `:list`.
  - `runtime_config`:
      Configuration map used during processing and report generation.
  """
  def process_files(execution_mode, :directory, directory_path, runtime_config) when is_binary(directory_path) do
    case File.dir?(directory_path) do
      true ->
        file_list =
          directory_path
          |> File.ls!()
          |> Enum.map(&Path.join(directory_path, &1))

        process_files(execution_mode, :list, file_list, runtime_config)

      false -> {:error, "Directory not found"}
    end
  end

  def process_files(execution_mode, :list, file_list, runtime_config) when is_list(file_list) do
    normalized_file_list = Enum.map(file_list, &get_path_and_name/1)

    case execution_mode do
      :sequential ->
        process_files_sequentially(normalized_file_list, runtime_config)

      :parallel ->
        process_files_in_parallel(normalized_file_list, runtime_config)

      :benchmark ->
        process_files_with_benchmark(normalized_file_list, runtime_config)
    end
  end

  # Error clauses for invalid data type
  def process_files(_execution_mode, :directory, _path), do: {:error, "Invalid argument, expected a string path"}
  def process_files(_execution_mode, :list, _file_list), do: {:error, "Invalid argument, expected a path list or a %Plug.Upload structure list"}

  # ----------------------------------------------------------------------
  # DATA NORMALIZATION
  # ----------------------------------------------------------------------

  @doc false
  # Normalizes different input formats into a standard `{file_path, file_name}` tuple.
  defp get_path_and_name(%Plug.Upload{path: file_path, filename: file_name}), do: {file_path, file_name}
  defp get_path_and_name(file_path) when is_binary(file_path), do: {file_path, Path.basename(file_path)}

  # Error clause for invalid input format.
  defp get_path_and_name(invalid), do: {:error, invalid, "Unsoported file format, expected a string path or a %Plug.Upload structure"}

  # ----------------------------------------------------------------------
  # EXECUTION MODES
  # ----------------------------------------------------------------------

  defp process_files_sequentially(file_list, runtime_config) do
    results =
      set_initial_metrics_map()
      |> process_file_list(file_list)

    FileProcessor.Report.generate({:sequential, results}, runtime_config)
  end

  defp process_files_in_parallel(file_list, runtime_config) do
    Parallel.Coordinator.start_parallel_processing(file_list, self(), runtime_config)

    receive do
      {:all_done, results} -> FileProcessor.Report.generate({:parallel, results}, runtime_config)
    end
  end

  defp process_files_with_benchmark(file_list, runtime_config) do
    {sequential_metrics, _} =
      Benchmark.measure(fn ->
        set_initial_metrics_map()
        |> process_file_list(file_list)
      end)

    {parallel_metrics, parallel_results} =
      Benchmark.measure(fn ->
        Parallel.Coordinator.start_parallel_processing(file_list, self(), runtime_config)
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
  defp process_file_list(acumulated_metrics, []), do: acumulated_metrics

  defp process_file_list(acumulated_metrics, [{file_path, file_name} | remaining_files]) do
    result = process_single_file({file_path, file_name})
    updated_metrics = update_metrics_map(acumulated_metrics, result)

    process_file_list(updated_metrics, remaining_files)
  end

  # ----------------------------------------------------------------------
  # FILE PROCESSING LOGIC
  # ----------------------------------------------------------------------

  @doc """
  Validates file existence and dispatches it to the correct processor
  based on the file extension.
  """
  def process_single_file({file_path, file_name}) when is_binary(file_path) do
    case File.exists?(file_path) do
      true ->
        file_name
        |> Path.extname()
        |> String.downcase()
        |> dispatch_file_by_extension({file_path, file_name})

      false ->
        {:error, file_name, "File not found"}
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
  defp dispatch_file_by_extension(".csv", {file_path, file_name}) do
    case FileProcessor.CsvProcessor.process_csv_file(file_path) do
      {:ok, metrics} ->
        {:ok, :csv, file_name, metrics}

      # {:error, reason} ->
        # {:error, Path.basename(file_path), reason}
    end
  end

  defp dispatch_file_by_extension(".json", {file_path, file_name}) do
    case FileProcessor.JsonProcessor.process_json_file(file_path) do
      {:ok, metrics} ->
        {:ok, :json, file_name, metrics}

      {:error, reason} ->
        {:error, file_name, reason}
    end
  end

  defp dispatch_file_by_extension(".log", {file_path, file_name}) do
    case FileProcessor.LogProcessor.process_log_files(file_path) do
      {:ok, metrics} ->
        {:ok, :log, file_name, metrics}

      {:error, reason} ->
        {:error, file_name, reason}
    end
  end

  # Error clause for unsupported file extensions.
  defp dispatch_file_by_extension(_extension, {_file_path, file_name}) do
    {:error, file_name, "Unsupported file type. Expected files with extension .csv, .json or .log"}
  end
end
