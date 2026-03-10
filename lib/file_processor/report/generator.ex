defmodule FileProcessor.Report.Generator do
  @moduledoc """
  Generates a human-readable report summarizing file processing results.

  Features:
  - Header with generation metadata.
  - Executive summary with total files processed and success rates.
  - Detailed sections for each file type (CSV, JSON, LOG).
  - Consolidated totals for CSV files.
  - Optional performance analysis for benchmark mode.
  - Detailed error logs for failed files or malformed data.
  """

  alias FileProcessor.Core.Metrics

  @sections [:csv, :json, :log]

  # ----------------------------------------------------------------------
  # PUBLIC API
  # ----------------------------------------------------------------------

  @doc """
  Entry point for the module.
  Generates a report from a map of processed results.

  ## Parameters
  - `metrics`: Metrics struct with processed results.
  - `processing_mode`: `:sequential`, `:parallel`, or `:benchmark`.
  - `config`: Optional configuration map. Can include `:report_name_label`.

  ## Returns
  - Updated `Metrics` struct including:
    - `:report` string
    - `:executive_summary` map
  """
  def build(%Metrics{} = metrics, processing_mode, config \\ %{}) do
    metrics = Metrics.add_metadata(metrics, {processing_mode, config})
    executive_summary = build_executive_summary_map(metrics)

    report_lines =
      []
      |> add_header(processing_mode)
      |> add_executive_summary(metrics, executive_summary)
      |> add_file_type_sections(metrics, @sections)
      |> add_performance_section(metrics, processing_mode)
      |> add_errors_section(metrics)
      |> Enum.join("\n")

    %{metrics |
      report: report_lines,
      executive_summary: executive_summary
    }
  end

  # ----------------------------------------------------------------------
  # HEADDER SECTION
  # ----------------------------------------------------------------------

  @doc false
  # Adds the header and metadata to the report.
  defp add_header(report_content, processing_mode) do
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
  defp add_executive_summary(report_content, metrics, executive_summary) do
    csv_entries = Map.get(metrics, :csv, [])
    json_entries = Map.get(metrics, :json, [])
    log_entries = Map.get(metrics, :log, [])

    csv_count = length(csv_entries)
    json_count = length(json_entries)
    log_count = length(log_entries)

    successfully_processed_files = executive_summary.successfully_processed_files
    success_rate_percentage = executive_summary.success_rate_percentage

    fatal_error_files = length(Map.get(metrics, :errors, []))

    files_with_internal_errors =
      (csv_entries ++ json_entries ++ log_entries)
      |> Enum.count(fn file -> Map.get(file.metrics, :errors_found, 0) > 0 end)

    total_error_files =
      fatal_error_files + files_with_internal_errors

    summary = [
      "--------------------------------------------------------------------------------",
      "EXECUTIVE SUMMARY",
      "--------------------------------------------------------------------------------",
      "Total files processed: #{successfully_processed_files}",
      "  - CSV Files: #{csv_count}",
      "  - JSON Files: #{json_count}",
      "  - LOG Files: #{log_count}",
      "",
      "Total error files: #{total_error_files}",
      "Success rate: #{success_rate_percentage}%"
    ]
    report_content ++ summary ++ [""]
  end

  # ----------------------------------------------------------------------
  # FILE TYPE METRICS SECTION
  # ----------------------------------------------------------------------

  @doc false
  # Iterates over file types to add their metrics and consolidated totals.
  defp add_file_type_sections(report_content, _metrics, []), do: report_content
  defp add_file_type_sections(report_content, metrics, [current_type | remaining_types]) do
    entries = Map.get(metrics, current_type, [])

    updated_report_content = if entries == [] do
      report_content
    else
      section_title = "#{format_key(current_type) |> String.upcase()} FILES METRICS"

      section_head = [
        "--------------------------------------------------------------------------------",
        section_title,
        "--------------------------------------------------------------------------------"
      ]

      formatted_entries =
        Enum.flat_map(entries, fn entry -> format_entry(entry, current_type) end)

      consolidated_data = add_consolidated_totals(entries, current_type)

      report_content ++ section_head ++ formatted_entries ++ consolidated_data ++ [""]
    end

    add_file_type_sections(updated_report_content, metrics, remaining_types)
  end

  # ----------------------------------------------------------------------
  # PERFORMANCE SECTION
  # ----------------------------------------------------------------------

  @doc false
  # Adds performance analysis section only if mode is :benchmark
  defp add_performance_section(report_content, metrics, :benchmark) do
    case Map.get(metrics, :performance) do
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
          "  * Processes used in total: #{performance.processes}",
          "  * Max processes used simultaneously: #{performance.max_processes_used}",
          "  * Memory used: #{performance.memory_max} MB",
          ""
        ]

        report_content ++ performance_section
    end
  end
  defp add_performance_section(report_content, _metrics, _mode), do: report_content

  # ----------------------------------------------------------------------
  # ERRORS SECTION
  # ----------------------------------------------------------------------

  @doc false
  # Adds fatal processing errors and internal file parsing errors.
  defp add_errors_section(report_content, metrics) do
    fatal_errors =
      Enum.map(metrics.errors, fn %{file: file, reason: reason} ->
        "#{file}: #{reason}"
      end)

    parsing_errors =
      [:csv, :json, :log]
      |> Enum.flat_map(fn file_type -> Map.get(metrics, file_type, []) end)
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
    key |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  @doc false
  # Formats a list with indentation for readability
  defp format_list(list) do
    list |> Enum.map(&"      - #{&1}") |> Enum.join("\n")
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

  defp build_executive_summary_map(results) do
    csv_count = length(Map.get(results, :csv, []))
    json_count = length(Map.get(results, :json, []))
    log_count = length(Map.get(results, :log, []))

    total_success = csv_count + json_count + log_count
    total_errors = length(Map.get(results, :errors, []))
    total_attempted = total_success + total_errors

    files_with_issues =
      [:csv, :json, :log]
      |> Enum.flat_map(fn type -> Map.get(results, type, []) end)
      |> Enum.count(fn file -> Map.get(file.metrics, :errors_found, 0) > 0 end)

    rate = if total_attempted > 0, do: Float.round((total_success / total_attempted) * 100, 1), else: 0

    %{
      total_files_attempted: total_attempted,
      successfully_processed_files: total_success,
      files_with_internal_errors: files_with_issues + total_errors,
      success_rate_percentage: rate
    }
  end
end
