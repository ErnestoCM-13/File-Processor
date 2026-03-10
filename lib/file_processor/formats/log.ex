defmodule FileProcessor.Formats.Log do
  @moduledoc """
  Specialized processor for CSV files.
  This module is delegated by `FileProcessor`when a `.log` file is detected.
  It parses each log entry usin regular expression, classifies entries by severity level,
  component and time, and calculates metrics.

  ## Calculated metrics:
  - Total number of entries
  - Distribution of levels (percentage)
  - Most problematic component (ERROR/FATAL only)
  - Most frequent error message pattern
  - peak logging hour
  - Error count and details for malformed lines
  """

  @behaviour FileProcessor.Formats.Processor

  # ----------------------------------------------------------------------
  # PUBLIC API
  # ----------------------------------------------------------------------

  @doc """
  Entry point for the module.
  Reads and processes a LOG file and returns a map
  containing calculated metrics.

  ## Processing flow
  1. Read file contents.
  2. Split into individual log lines.
  3. Parse and classify each line.
  4. Accumulate line data.
  5. Calculate final metrics
  """
  @impl true
  def process(log_file_path) do
    with {:ok, file_content} <- File.read(log_file_path) do
      lines = String.split(file_content, "\n", trim: true)

      metrics =
        set_initial_metrics_accumulator()
        |> process_lines(lines)
        |> build_final_metrics()

      {:ok, metrics}

    else
      {:error, :enoent} -> {:error, "File not found #{log_file_path}"}
    end
  end

  # ----------------------------------------------------------------------
  # ACCUMULATOR INITIALIZATION
  # ----------------------------------------------------------------------

  @doc false
  # Initializes the accumulator with default values for LOG metrics.
  defp set_initial_metrics_accumulator() do
    %{
      total_entries: 0,
      levels: %{},          # %{"ERROR" => 5, "INFO" => 10}
      components: %{},      # %{"DB" => 3} (only for errores/fatals)
      entries_by_hours: %{},       # %{14 => 20}
      message_occurrences: %{},        # %{"connection timeout" => 4}
      malformed_lines: []
    }
  end

  # ----------------------------------------------------------------------
  # LOG LINE PROCESSING
  # ----------------------------------------------------------------------

  @doc false
  # Iterates over the list of lines, parsing them using the parse_line/1 function.
  defp process_lines(accumulator, []), do: accumulator
  defp process_lines(accumulator, [first_line | remaining_lines]) do
    updated_accumulator =
      case parse_line(first_line) do
        {:ok, parsed_line} -> update_accumulator(accumulator, parsed_line)

        {:error, _reason} ->
          Map.update!(accumulator, :malformed_lines, fn errors ->
            ["Invalid log format: #{first_line}" | errors]
          end)
      end

    process_lines(updated_accumulator, remaining_lines)
  end

  # ----------------------------------------------------------------------
  # ACCUMULATION LOGIC
  # ----------------------------------------------------------------------

  @doc false
  # Updates the accumulator data with information from a successfully parsed line.
  # Calls the update_error_components/2 function to update components only in case of error.
  defp update_accumulator(accumulator, parsed_line) do
    %{
      accumulator |
      total_entries: accumulator.total_entries + 1,
      levels:
        Map.update(
          accumulator.levels,
          parsed_line.level,
          1,
          &(&1 + 1)
        ),
      entries_by_hours:
        Map.update(
          accumulator.entries_by_hours,
          parsed_line.hour,
          1,
          &(&1 + 1)
        ),
      components:
        update_error_components(
          accumulator.components,
          parsed_line
        ),
      message_occurrences:
        Map.update(
          accumulator.message_occurrences,
          parsed_line.message,
          1,
          &(&1 + 1)
        )
    }
  end

  @doc false
  # Update components only in case of error.
  defp update_error_components(components_map, %{level: level, component: component}) when level in ["ERROR", "FATAL"] do
    Map.update(components_map, component, 1, &(&1 + 1))
  end

  defp update_error_components(components_map, _), do: components_map

  # ----------------------------------------------------------------------
  # LINE PARSING
  # ----------------------------------------------------------------------

  @doc false
  # Uses a Regex to capture five information groups:
  # Date, Time (HH), Level, Component, and Message.
  # Expected format: YYYY-MM-DD HH:mm:ss [LEVEL] [COMPONENT] MESSAGE
  defp parse_line(line) do
    log_regex =
      ~r/^(\d{4}-\d{2}-\d{2})\s(\d{2}):\d{2}:\d{2}\s\[(\w+)\]\s\[(\w+)\]\s(.*)$/

    case Regex.run(log_regex, line) do
      [_full, date, hour, level, component, message] ->
        {:ok,
          %{
            date: date,
            hour: String.to_integer(hour),
            level: level,
            component: component,
            message: message
        }}

      nil ->
        {:error, "Invalid line format"}
    end
  end

  # ----------------------------------------------------------------------
  # FINAL METRICS CALCULATION
  # ----------------------------------------------------------------------

  @doc false
  # Uses the accumulator data to calculate metrics and stores them in a map with
  # data that the Report module can convert into a string.
  defp build_final_metrics(accumulator) do
    # Identifies the component with the highest incidence of critical failures.
    {top_component, component_error_count} =
      if map_size(accumulator.components) > 0 do
        accumulator.components
        |> Enum.sort_by(fn {component, count} -> {-count, component} end)
        |> List.first()
      else
        {"None", 0}
      end

    # Identifies the most frequent root cause (repeated message).
    {top_message, message_count} =
      if map_size(accumulator.message_occurrences) > 0 do
        accumulator.message_occurrences
        |> Enum.sort_by(fn {message, count} -> {-count, message} end)
        |> List.first()
      else
        {"N/A", 0}
      end

    %{
      total_entries: accumulator.total_entries,
      level_distribution: calculate_level_distribution(accumulator.levels, accumulator.total_entries),
      most_problematic_component: "#{top_component} (#{component_error_count} errors)",
      frequent_error_pattern: "#{top_message} (#{message_count} occurrences)",
      peak_log_hour: determine_peak_hour(accumulator.entries_by_hours),
      errors_found: length(accumulator.malformed_lines),
      error_details: accumulator.malformed_lines
    }
  end

  # ----------------------------------------------------------------------
  # METRIC HELPERS
  # ----------------------------------------------------------------------

  @doc false
  # Converts the level map into a list of percentages (e.g., ["INFO: 70%", "ERROR: 10%"])
  defp calculate_level_distribution(_levels, 0), do: "None"
  defp calculate_level_distribution(levels, total_entries) do
    levels
    |> Enum.sort()
    |> Enum.map(fn {level, count} ->
      percentage = Float.round((count / total_entries) * 100, 1)
      "#{level}: #{percentage}%"
    end)
  end

  @doc false
  # Determines the time interval with the highest logging activity.
  defp determine_peak_hour(hours_map) do
    if map_size(hours_map) > 0 do
      {hour, _count} =
        Enum.max_by(hours_map, fn {_hour, count} -> count end)

      "#{hour}:00"
    else
      "N/A"
    end
  end
end
