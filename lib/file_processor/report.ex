defmodule FileProcessor.Report do
  @moduledoc """
  Specialized report generator.
  This module generates a human-readable summary including:

  - Header with generation metadata.
  - Executive summary with total files processed and success rates.
  - Detailed sections for each file type (CSV, JSON, LOG).
  - Consolidated totals for CSV files.
  - Optional performance analysis for benchmark mode.
  - Detailed error logs for failed files or malformed data.
  """

  # ----------------------------------------------------------------------
  # PUBLIC API
  # ----------------------------------------------------------------------

  @doc """
  Entry point for the module.
  Generates a report from a map of processed results.

  ## Parameters
  - `results_tuple`: Tuple of `{mode, results}` where:
      - `mode` is either `:sequential`, `:parallel`, or `:benchmark`.
      - `results` is a map with keys for each file type and errors.
  - `config`: Optional configuration map. Can include:
      - `:report_name_label` - custom label for the report filename.

  ## Data flow
  1. Creates an output directory if it doesn't exist.
  2. Builds the report content sequentially:
     Header -> Executive Summary -> Sections -> Performance Analysis -> Errors.
  3. Writes the content to a `.txt` file with a timestamp in the name.

  ## Returns
  - `{:ok, message}` on success
  - `{:error, reason}` on failure
  """
  def generate({processing_mode, processed_results}, config \\ %{}) when is_map(processed_results) do
    report_name_label =
      Map.get(config, :report_name_label) || NaiveDateTime.local_now()

    output_path =
      "output/final_report_#{processing_mode}_#{report_name_label}.txt"

    Path.dirname(output_path) |> File.mkdir_p!()

    sections_to_process = [:csv, :json, :log]

    report_content =
      []
      |> add_report_header(processing_mode)
      |> add_executive_summary(processed_results)
      |> add_file_type_sections(processed_results, sections_to_process)
      |> add_performance_analysis_section(processed_results, processing_mode)
      |> add_errors_section(processed_results)
      |> Enum.join("\n")

    case File.write(output_path, report_content) do
      :ok -> {:ok, "Report generated successfully: #{output_path}"}
      {:error, reason} -> {:error, "Error writing report: #{reason}"}
    end
  end

  # ----------------------------------------------------------------------
  # HEADDER SECTION
  # ----------------------------------------------------------------------

  @doc false
  # Adds the header and metadata to the report.
  defp add_report_header(report_content, processing_mode) do
    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S")
    header_section =
      [
        "================================================================================",
        "                    PROCESSED FILES REPORT",
        "================================================================================",
        "",
        "Generation date: #{timestamp}",
        "Processed path: #{File.cwd!()}",
        "Process mode: #{format_key(processing_mode)}"
      ]

    report_content ++ header_section ++ [""]
  end

  # ----------------------------------------------------------------------
  # EXECUTIVE SUMMARY SECTION
  # ----------------------------------------------------------------------

  @doc false
  # Calculates and adds global statistics and appends an executive summary section.
  defp add_executive_summary(report_content, processed_results) do
    csv_entries = Map.get(processed_results, :csv, [])
    json_entries = Map.get(processed_results, :json, [])
    log_entries = Map.get(processed_results, :log, [])

    csv_count = length(csv_entries)
    json_count = length(json_entries)
    log_count = length(log_entries)

    successfully_processed_files =
      csv_count + json_count + log_count

    fatal_error_files =
      length(Map.get(processed_results, :errors, []))

    files_with_internal_errors =
      (csv_entries ++ json_entries ++ log_entries)
      |> Enum.count(fn file -> Map.get(file.metrics, :errors_found, 0) > 0 end)

    clean_files =
      (csv_entries ++ json_entries ++ log_entries)
      |> Enum.count(fn file -> Map.get(file.metrics, :errors_found, 0) == 0 end)

    files_with_internal_errors =
      fatal_error_files + files_with_internal_errors

    total_files_attempted =
      successfully_processed_files + fatal_error_files

    success_rate_percentage =
      if total_files_attempted > 0, do: Float.round((clean_files / total_files_attempted) * 100, 1), else: 0

    summary = [
      "--------------------------------------------------------------------------------",
      "EXECUTIVE SUMMARY",
      "--------------------------------------------------------------------------------",
      "Total files processed: #{successfully_processed_files}",
      "  - CSV Files: #{csv_count}",
      "  - JSON Files: #{json_count}",
      "  - LOG Files: #{log_count}",
      "",
      "Total error files: #{files_with_internal_errors}",
      "Success rate: #{success_rate_percentage}%"
    ]
    report_content ++ summary ++ [""]
  end

  # ----------------------------------------------------------------------
  # FILE TYPE METRICS SECTION
  # ----------------------------------------------------------------------

  @doc false
  # Iterates over file types to add their metrics and consolidated totals.
  defp add_file_type_sections(report_content, _processed_results, []), do: report_content
  defp add_file_type_sections(report_content, processed_results, [current_type | remaining_types]) do
    current_type_entries = Map.get(processed_results, current_type, [])

    updated_report_content = if current_type_entries == [] do
      report_content
    else
      title = "#{format_key(current_type) |> String.upcase()} FILES METRICS"

      section_head = [
        "--------------------------------------------------------------------------------",
        title,
        "--------------------------------------------------------------------------------"
      ]

      current_type_formatted_entries =
        Enum.flat_map(current_type_entries, fn entry -> format_entry(entry, current_type) end)

      consolidated_data =
        add_consolidated_totals(current_type_entries, current_type)

      report_content ++ section_head ++ current_type_formatted_entries ++ consolidated_data ++ [""]
    end

    add_file_type_sections(updated_report_content, processed_results, remaining_types)
  end

  # ----------------------------------------------------------------------
  # PERFORMANCE ANALYSIS SECTION
  # ----------------------------------------------------------------------

  @doc false
  # Adds performance analysis section only if mode is :benchmark
  defp add_performance_analysis_section(report_content, processed_results, :benchmark) do
    case Map.get(processed_results, :performance) do
      nil ->
        report_content

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

        report_content ++ performance_section
    end
  end
  defp add_performance_analysis_section(report_content, _processed_results, _mode), do: report_content

  # ----------------------------------------------------------------------
  # ERRORS SECTION
  # ----------------------------------------------------------------------

  @doc false
  # Adds fatal processing errors and internal file parsing errors.
  defp add_errors_section(report_content, []), do: report_content
  defp add_errors_section(report_content, processed_results) do
    # Errors that prevented a file from being processed
    fatal_errors =
      Enum.map(processed_results.errors, fn %{file: file, reason: reason} ->
        "#{file}: #{reason}"
      end)

    # Errors found inside correctly processed files (malformed lines)
    parsing_errors =
      [:csv, :json, :log]
      |> Enum.flat_map(fn file_type -> Map.get(processed_results, file_type, []) end)
      |> Enum.filter(fn entry -> Map.get(entry.metrics, :errors_found, 0) > 0 end)
      |> Enum.map(fn entry ->
        "#{entry.file}: #{entry.metrics.errors_found} invalid entries found.
        \n  Details: \n    #{Enum.join(entry.metrics.error_details, "\n    ")}"
      end)

    all_errors = fatal_errors ++ parsing_errors

    case all_errors do
      [] ->
        report_content

      _ ->
        error_section =
          [
            "--------------------------------------------------------------------------------",
            "ERRORS",
            "--------------------------------------------------------------------------------"
          ] ++ all_errors

        report_content ++ error_section
    end
  end

  # ----------------------------------------------------------------------
  # FORMATTING HELPERS
  # ----------------------------------------------------------------------

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
    formatted_top_actions = format_list(metrics.top_5_actions)
    [
      "[File: #{file}]",
      "  * Registered users: #{metrics.total_users}",
      "  * Active users: #{metrics.active_users} (#{metrics.active_percent}%)",
      "  * Avg session duration: #{metrics.avg_session_duration}",
      "  * Total pages visited: #{metrics.total_pages_visited}",
      "  * Top 5 actions: \n#{formatted_top_actions}"
    ]
  end

  defp format_entry(%{file: file, metrics: metrics}, :log) do
    formatted_level_distribution = format_list(metrics.level_distribution)
    [
      "[File: #{file}]",
      "  * Total entries: $#{metrics.total_entries}",
      "  * Level distribution: \n#{formatted_level_distribution}",
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
  # Formats a list with indentation for readability
  defp format_list(list) do
    list
    |> Enum.map(&"      - #{&1}")
    |> Enum.join("\n")
  end

  @doc false
  # Calculates overall totals for CSV files to show at the end of the section.
  defp add_consolidated_totals(entries, :csv) do
    total_sales =
      Enum.reduce(entries, 0, fn entry, acc -> acc + entry.metrics.total_sales end)

    [
      "",
      "CSV Consolidated totals:",
      "  - Total sales: $#{total_sales}"
    ]
  end
  defp add_consolidated_totals(_entries, _type), do: []
end
