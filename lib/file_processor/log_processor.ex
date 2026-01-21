defmodule FileProcessor.LogProcessor do
  @moduledoc """
  Specialized processor for CSV files, delegated by `FileProcessor`.
  Extracts data and calculates metrics using Regex.
  Calculated metrics:
  - total entries
  - level distribution
  - most problematic component
  - frequent error pattern
  - peak log hour
  """

  @doc """
  Entry point for the module.
  process a JOG file and returns a map of calculated metrics.

  ## Data flow
  1. File reading.
  2. Line parsing using regex.
  3. Classify each entry.
  4. Metrics calculation.
  """
  def process(path) do
    with {:ok, content} <- File.read(path) do
      lines = String.split(content, "\n", trim: true)

      metrics =
        set_initial_accumulator()
        |> process_lines(lines)
        |> finalize_metrics()

      {:ok, metrics}

    else
      {:error, :enoent} -> {:error, "File not found #{path}"}
    end
  end

  @doc false
  # Initializes the accumulator with default values for LOG metrics.
  defp set_initial_accumulator() do
    %{
      total_entries: 0,
      levels: %{},      # %{"ERROR" => 5, "INFO" => 10}
      components: %{},  # %{"DB" => 3} (only for errores/fatals)
      hours: %{},       # %{14 => 20}
      messages: %{},
      line_errors: []
    }
  end

  # --- RECURSIVE LOGIC ---

  @doc false
  # Iterates over the list of lines, parsing them using the parse_line/1 function.
  defp process_lines(accumulator, []), do: accumulator
  defp process_lines(accumulator, [head_line | tail]) do
    new_accumulator =
      case parse_line(head_line) do
        {:ok, data} -> update_accumulator(accumulator, data)

        {:error, _reason} ->
          Map.update!(accumulator, :line_errors, fn errors ->
            ["Invalid log format: #{String.slice(head_line, 0, 30)}..." | errors]
          end)
      end

    process_lines(new_accumulator, tail)
  end

  @doc false
  # Updates the accumulator data with information from a successfully parsed line.
  # Calls the update_error_components/2 function to update components only in case of error.
  defp update_accumulator(accumulator, data) do
    %{
      accumulator |
      total_entries: accumulator.total_entries + 1,
      levels: Map.update(accumulator.levels, data.level, 1, &(&1 + 1)),
      hours: Map.update(accumulator.hours, data.hour, 1, &(&1 + 1)),
      components: update_error_components(accumulator.components, data),
      messages: Map.update(accumulator.messages, data.message, 1, &(&1 + 1))
    }
  end

  @doc false
  # Update components only in case of error.
  defp update_error_components(components_map, %{level: level, component: component}) when level in ["ERROR", "FATAL"] do
    Map.update(components_map, component, 1, &(&1 + 1))
  end
  defp update_error_components(components_map, _), do: components_map

  # --- DATA PARSING ---

  @doc false
  # Uses a Regex to capture five information groups:
  # Date, Time (HH), Level, Component, and Message.
  # Expected format: YYYY-MM-DD HH:mm:ss [LEVEL] [COMPONENT] MESSAGE
  defp parse_line(line) do
    regex = ~r/^(\d{4}-\d{2}-\d{2})\s(\d{2}):\d{2}:\d{2}\s\[(\w+)\]\s\[(\w+)\]\s(.*)$/

    case Regex.run(regex, line) do
      [_full, date, hour, level, component, message] ->
        {:ok, %{
          date: date,
          hour: String.to_integer(hour),
          level: level,
          component: component,
          message: message
        }}

      nil -> {:error, "Invalid line format"}
    end
  end

  # --- METRICS CALCULATION ---

  @doc false
  # Uses the accumulator data to calculate metrics and stores them in a map with
  # data that the Report module can convert into a string.
  defp finalize_metrics(accumulator) do
    # Identifies the component with the highest incidence of critical failures.
    {top_component, error_count} =
      if map_size(accumulator.components) > 0,
      do: Enum.max_by(accumulator.components, fn {_component, count} -> count end),
      else: {"None", 0}

    # Identifies the most frequent root cause (repeated message).
    {top_message, message_count} =
      if map_size(accumulator.messages) > 0,
      do: Enum.max_by(accumulator.messages, fn {_message, count} -> count end),
      else: {"N/A", 0}

    %{
      total_entries: accumulator.total_entries,
      level_distribution: calculate_distribution(accumulator.levels, accumulator.total_entries),
      most_problematic_component: "#{top_component} (#{error_count} errors)",
      frequent_error_pattern: "#{top_message} (#{message_count} ocurrences)",
      peak_log_hour: find_peak_hour(accumulator.hours),
      errors_found: length(accumulator.line_errors),
      error_details: accumulator.line_errors
    }
  end

  @doc false
  # Converts the level map into a list of percentages (e.g., ["INFO: 70%", "ERROR: 10%"])
  defp calculate_distribution(_levels, 0), do: "None"
  defp calculate_distribution(levels, total_entries) do
    levels
    |> Enum.map(fn {level, count} ->
      percent = Float.round((count / total_entries) * 100, 1)
      "#{level}: #{percent}%"
    end)
  end

  @doc false
  # Determines the time interval with the highest logging activity.
  defp find_peak_hour(hours) do
    if map_size(hours) > 0 do
      {hour, _} = Enum.max_by(hours, fn {_, count} -> count end)
      "#{hour}:00"
    else
      "N/A"
    end
  end
end
