defmodule FileProcessor do
  @moduledoc """
  Main module for the file processor.
  It is responsible for:
  1. Finding files (via `directories` or explicit `lists`).
  2. Classifying by file extension.
  3. Applying the execution mode (`Sequential`, `Parallel`, or `Benchmark`).
  4. Receiving metrics from processed files.
  5. Sending them to the report generator.
  """

  # --- PUBLIC API ---

  @doc """
  Main entry point. Starts processing according to the execution mode.

  ## Parameters
  - `mode`: An atom that determines the execution mode (`:parallel`, `:sequential`, `:benchmark`).
  - `source_type`: An atom that defines whether the third argument is a `:directory` or a `:list` of paths.
  - `path` or `path_list`: A string containing the directory path or a list of strings containing file paths.
  - `config`: Map containing runtime configurations
  """
  def process_files(mode, :directory, path, config) when is_binary(path) do
    case File.dir?(path) do
      true ->
        path_list =
          path
          |> File.ls!()
          |> Enum.map(&Path.join(path, &1))

        process_files(mode, :list, path_list, config)

      false -> {:error, "Directory not found"}
    end
  end

  def process_files(mode, :list, path_list, config) when is_list(path_list) do
    case mode do
      :parallel ->
        Parallel.Coordinator.start(path_list, self(), config)

        receive do
          {:all_done, results} -> FileProcessor.Report.generate({:parallel, results}, config)
        end

      :sequential ->
        results =
          set_initial_metrics_map()
          |> process_paths(path_list)

        FileProcessor.Report.generate({:sequential, results}, config)

      :benchmark ->
        {sequential_metrics, _} =
          Benchmark.measure(fn ->
            set_initial_metrics_map() |> process_paths(path_list)
          end)

        {parallel_metrics, parallel_results} =
          Benchmark.measure(fn ->
            Parallel.Coordinator.start(path_list, self(), config)
            receive do: ({:all_done, results} -> results)
          end)

        performance = Benchmark.calculate_performance(sequential_metrics, parallel_metrics)

        final_results = Map.put(parallel_results, :performance, performance)

        FileProcessor.Report.generate({:benchmark, final_results}, config)
    end
  end

  # Error clauses for invalid data type
  def process_files(_mode, :directory, _path), do: {:error, "Invalid argument, expected a string path"}
  def process_files(_mode, :list, _path_list), do: {:error, "Invalid argument, expected a paths list"}

  # --- INTERNAL LOGIC ---

  @doc false
  # Recursive function to iterate through the path list for the sequential mode
  defp process_paths(grouped_metrics, []), do: grouped_metrics

  defp process_paths(grouped_metrics, [head_path | tail]) do
    result = process_path(head_path)
    new_grouped_metrics = update_metrics_map(grouped_metrics, result)

    process_paths(new_grouped_metrics, tail)
  end

  @doc """
  Validates file existence and dispatches its processing based on the file extension.
  """
  def process_path(path) when is_binary(path) do
    case File.exists?(path) do
      true ->
        extension = path |> Path.extname() |> String.downcase()

        dispatch_file(extension, path)

      false -> {:error, Path.basename(path), "File not found"}
    end
  end

  # Error clause for invalid data type.
  def process_path(path), do: {:error, path, "Invalid argument, expected a string path"}

  @doc """
  Initializes the data structure to store metrics.
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
  Update the accumulator metrics, adding results or errors.
  """
  def update_metrics_map(grouped_metrics, {:ok, type, file, metrics}) do
    Map.update!(grouped_metrics, type, fn list ->
      [%{file: file, metrics: metrics, internal_errors: Map.get(metrics, :error_lines, [])} | list]
    end)
  end

  def update_metrics_map(grouped_metrics, {:error, file, reason}) do
    Map.update!(grouped_metrics, :errors, fn list ->
      [%{file: file, reason: reason} | list]
    end)
  end

  # --- DISPATCH FUNCTIONS ---

  @doc false
  # These functions connect to specialized processing modules.
  defp dispatch_file(".csv", path) do
    case FileProcessor.CsvProcessor.process(path) do
      {:ok, metrics} -> {:ok, :csv, Path.basename(path), metrics}
      {:error, reason} -> {:error, Path.basename(path), reason}
    end
  end

  defp dispatch_file(".json", path) do
    case FileProcessor.JsonProcessor.process(path) do
      {:ok, metrics} -> {:ok, :json, Path.basename(path), metrics}
      {:error, reason} -> {:error, Path.basename(path), reason}
    end
  end

  defp dispatch_file(".log", path) do
    case FileProcessor.LogProcessor.process(path) do
      {:ok, metrics} -> {:ok, :log, Path.basename(path), metrics}
      {:error, reason} -> {:error, Path.basename(path), reason}
    end
  end

  # Error clause unsupported file extensions.
  defp dispatch_file(_extension, path) do
    {:error, Path.basename(path), "Unsupported file type, expected files with extension .csv, .json or .log"}
  end
end
