defmodule FileProcessor.Report do
  @moduledoc """
  Specialized report generator.
  This module generates a human-readable summary including headers,
  categorized metrics for each file type, and a detailed error log.
  """

  @doc """
  Entry point for the module.
  Generates a report from a map of results.

  ## Data flow
  1. Creates an output directory if it doesn't exist.
  2. Builds the report content sequentially: Header -> Metrics -> Errors.
  3. Writes the content to a `.txt` file with a timestamp in the name.
  """
  def generate({mode, results}) when is_map(results) do
    output_path = "output/final_report_#{mode}_#{NaiveDateTime.local_now()}.txt"
    Path.dirname(output_path) |> File.mkdir_p!()
    sections_to_process = [:csv, :json, :log]

    content =
      []
      |> add_header(mode)
      |> add_executive_summary(results)
      |> add_sections(results, sections_to_process)
      |> add_performance_analysis(results, mode)
      |> add_errors(results)
      |> Enum.join("\n")

    case File.write(output_path, content) do
      :ok -> {:ok, "Report generated successfully: #{output_path}"}
      {:error, reason} -> {:error, "Error writing report: #{reason}"}
    end
  end

  # --- REPORT SECTIONS ---

  @doc false
  # Adds the header and metadata to the report.
  defp add_header(content, mode) do
    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S")
    header =
      [
        "================================================================================",
        "                    PROCESSED FILES REPORT",
        "================================================================================",
        "",
        "Generation date: #{timestamp}",
        "Processed path: #{File.cwd!()}",
        "Process mode: #{format_key(mode)}"
      ]

    content ++ header ++ [""]
  end

  @doc false
  # Calculates and adds an overview of success rates and file counts.
  defp add_executive_summary(content, results) do
    csv_entries = Map.get(results, :csv, [])
    json_entries = Map.get(results, :json, [])
    log_entries = Map.get(results, :log, [])

    csv_count = length(csv_entries)
    json_count = length(json_entries)
    log_count = length(log_entries)

    successed_files = csv_count + json_count + log_count
    fatal_errors = length(Map.get(results, :errors, []))
    clean_files =
      (csv_entries ++ json_entries ++ log_entries)
      |> Enum.count(fn entry -> Map.get(entry.metrics, :errors_found, 0) == 0 end)
    files_with_internal_errors =
      (csv_entries ++ json_entries ++ log_entries)
      |> Enum.count(fn entry -> Map.get(entry.metrics, :errors_found, 0) > 0 end)

    total_files_with_errors = fatal_errors + files_with_internal_errors

    total_attempted = successed_files + fatal_errors
    success_rate = if total_attempted > 0, do: Float.round((clean_files / total_attempted) * 100, 1), else: 0

    summary = [
      "--------------------------------------------------------------------------------",
      "EXECUTIVE SUMMARY",
      "--------------------------------------------------------------------------------",
      "Total files processed: #{successed_files}",
      "  - CSV Files: #{csv_count}",
      "  - JSON Files: #{json_count}",
      "  - LOG Files: #{log_count}",
      "",
      "Total error files: #{total_files_with_errors}",
      "Success rate: #{success_rate}%"
    ]
    content ++ summary ++ [""]
  end

  @doc false
  # Iterates over file types to add their metrics and consolidated totals.
  defp add_sections(content, _results, []), do: content
  defp add_sections(content, results, [current_type | tail]) do
    entries = Map.get(results, current_type, [])

    new_content = if entries == [] do
      content
    else
      title = "#{format_key(current_type) |> String.upcase()} FILES METRICS"
      section_head = [
        "--------------------------------------------------------------------------------",
        title,
        "--------------------------------------------------------------------------------"
      ]

      formatted_entries = Enum.flat_map(entries, fn entry -> format_entry(entry, current_type) end)

      consolidated_data = add_consolidated(entries, current_type)

      content ++ section_head ++ formatted_entries ++ consolidated_data ++ [""]
    end

    add_sections(new_content, results, tail)
  end

  @doc false
  # Appends hardware and timing comparison data only if the mode is :benchmark.
  defp add_performance_analysis(content, results, :benchmark) do
    case Map.get(results, :performance) do
      nil -> content
      performance ->
        performance_section = [
          "--------------------------------------------------------------------------------",
          "PERFORMANCE ANALYSIS",
          "--------------------------------------------------------------------------------",
          "Sequential vs Parallel Comparison:",
          "  * Sequential time: #{Float.round(performance.sequential_time, 4)} seconds",
          "  * Parallel time: #{Float.round(performance.parallel_time, 4)} seconds",
          "  * Improvement: #{performance.improvement} times faster",
          "  * Processes used: #{performance.processes}",
          "  * Memory used: #{performance.memory_max} MB",
          ""
        ]
        content ++ performance_section
    end
  end
  defp add_performance_analysis(content, _results, _mode), do: content

  @doc false
  # Adds both fatal processing errors and internal file parsing errors.
  defp add_errors(content, []), do: content
  defp add_errors(content, results) do
    # Errors that prevented a file from being processed
    fatal_errors =
      Enum.map(results.errors, fn %{file: file, reason: reason} ->
        "#{file}: #{reason}"
      end)

      # Errors found inside correctly processed files (malformed lines)
    parsing_errors =
      [:csv, :json, :log]
      |> Enum.flat_map(fn type -> Map.get(results, type, []) end)
      |> Enum.filter(fn entry -> Map.get(entry.metrics, :errors_found, 0) > 0 end)
      |> Enum.map(fn entry ->
        "#{entry.file}: #{entry.metrics.errors_found} invalid entries found. \n  Details: \n    #{Enum.join(entry.metrics.error_details, "\n    ")}"
      end)

    all_errors = fatal_errors ++ parsing_errors

    case all_errors do
      [] ->
        content

      _ ->
        section =
          [
            "--------------------------------------------------------------------------------",
            "ERRORS",
            "--------------------------------------------------------------------------------"
          ] ++ all_errors
        content ++ section
    end
  end

  # --- FORMATING HELPERS ---

  @doc false
  # Converts an entry's metric map into a structured list of strings.
  defp format_entry(%{file: file, metrics: metrics}, :csv) do
    [
      "[File: #{file}]",
      "  * Total sales: $#{metrics.total_sales}",
      "  * Unique products: #{metrics.unique_products}",
      "  * Top product: #{metrics.top_product}",
      "  * Top category: #{metrics.top_category}",
      "  * Average discount: #{metrics.average_discount}",
      "  * Date range: #{metrics.date_range}"
    ]
  end

  defp format_entry(%{file: file, metrics: metrics}, :json) do
    [
      "[File: #{file}]",
      "  * Registered users: #{metrics.total_users}",
      "  * Active users: #{metrics.active_users} (#{metrics.active_percent}%)",
      "  * Avg session duration: #{metrics.avg_session_duration}",
      "  * Total pages visited: #{metrics.total_pages_visited}",
      "  * Top 5 actions:",
      "    - #{metrics.top_5_actions}"
    ]
  end

  defp format_entry(%{file: file, metrics: metrics}, :log) do
    [
      "[File: #{file}]",
      "  * Total entries: $#{metrics.total_entries}",
      "  * Level distribution:",
      "    - #{metrics.level_distribution}",
      "  * Most problematic component: #{metrics.most_problematic_component}",
      "  * Frequent error pattern: #{metrics.frequent_error_pattern}"
    ]
  end

  @doc false
  # Converts internal atoms into human-readable labels
  defp format_key(key) do
    key
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  @doc false
  # Calculates overall totals for CSV files to show at the end of the section.
  defp add_consolidated(entries, :csv) do
    total_sales = Enum.reduce(entries, 0, fn e, acc -> acc + e.metrics.total_sales end)
    [
      "",
      "CSV Consolidated totals:",
      "  - Total sales: $#{total_sales}"
    ]
  end
  defp add_consolidated(_entries, _type), do: []
end
