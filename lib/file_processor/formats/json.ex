defmodule FileProcessor.Formats.Json do
  @moduledoc """
  Specialized processor for JSON files
  This module is delegated by `FileProcessor` when a `.json` file is detected.
  It reads and decodes the file using `Jason`, validates its contents, accumulates
  data for users and sessions, and calculates metrics.

  ## Expected JSON structure
  The root JSON object is expected to contain:
  - "usuarios": list of user objects
  - "sesiones": list of session objects

  ## Calculated metrics:
  - Total number of users
  - Percentage of active users
  - Average session duration (in minutes)
  - Total pages visited
  - Top 5 most frequent actions
  - Peak usage hour
  - Total number of sessions
  - Error count and details
  """

  @behaviour FileProcessor.Formats.Processor

  # ----------------------------------------------------------------------
  # PUBLIC API
  # ----------------------------------------------------------------------

  @doc """
  Entry point for the module.
  Reads, decodes, and processes a JSON file and returns a map
  containing calculated metrics.

  ## Processing flow
  1. Read file contents
  2. Decode JSON strings into Elixir maps.
  3. Accumulate users list data.
  4. Accumulate sessions list data.
  5. Calculate final metrics.

  Retorns `{:ok, metrics}` on succes or `{:error, reason}` if the file
  cannot be read or decoded.
  """
  @impl true
  def process(json_file_path) do
    with {:ok, raw_content} <- File.read(json_file_path),
         {:ok, decoded_json} <- Jason.decode(raw_content) do

      metrics =
        set_initial_metrics_accumulator()
        |> process_user_list(Map.get(decoded_json, "usuarios", []))
        |> process_session_list(Map.get(decoded_json, "sesiones", []))
        |> build_final_metrics()

      {:ok, metrics}
    else
      {:error, %Jason.DecodeError{}} ->
        {:error, "Malformed JSON file"}

      {:error, reason} ->
        {:error, "Read error: #{reason}"}
    end
  end

  # ----------------------------------------------------------------------
  # ACCUMULATOR INITIALIZATION
  # ----------------------------------------------------------------------

  @doc false
  # Initializes the data accumulator with default values for JSON metrics.
  defp set_initial_metrics_accumulator() do
    %{
      total_users: 0,
      active_users: 0,
      inactive_users: 0,
      total_sessions: 0,
      total_session_duration_seconds: 0,
      total_pages_visited: 0,
      action_ocurrences: %{}, # %{"click" => 5, "login" => 2}
      sessions_by_hour: %{},    # %{hour => sesions}
      data_errors: []
    }
  end

  # ----------------------------------------------------------------------
  # USER PROCESSING
  # ----------------------------------------------------------------------

  @doc false
  # Iterates over the "usuarios" list, validating them using the validate_and_parse_user/1 function.
  defp process_user_list(accumulator, []), do: accumulator
  defp process_user_list(accumulator, [first_user | remaining_users]) do
    updated_accumulator =
      case validate_and_parse_user(first_user) do
        {:ok, user_data} ->
          update_user_accumulator(accumulator, user_data)

        {:error, error_message} ->
          Map.update!(accumulator, :data_errors, &([error_message | &1]))
      end

    process_user_list(updated_accumulator, remaining_users)
  end

  @doc false
  # Updates the accumulator data with information from a successfully parsed user.
  defp update_user_accumulator(accumulator, user_data) do
    case user_data.active do
      true -> %{accumulator |
          total_users: accumulator.total_users + 1,
          active_users: accumulator.active_users + 1
        }
      false -> %{accumulator |
          total_users: accumulator.total_users + 1,
          inactive_users: accumulator.inactive_users + 1
        }
    end
  end

  # ----------------------------------------------------------------------
  # SESSION PROCESSING
  # ----------------------------------------------------------------------

  @doc false
  # Iterates over the "sesiones" list, validating them using the validate_and_parse_session/1 function.
  defp process_session_list(accumulator, []), do: accumulator
  defp process_session_list(accumulator, [first_sesion | remaining_sessions]) do
    updated_accumulator =
      case validate_and_parse_session(first_sesion) do
        {:ok, session_data} ->
          update_session_accumulator(accumulator, session_data)

        {:error, error_message} ->
          Map.update!(accumulator, :data_errors, &([error_message | &1]))
      end

    process_session_list(updated_accumulator, remaining_sessions)
  end

  @doc false
  # Updates the accumulator data with information from a successfully parsed session.
  defp update_session_accumulator(accumulator, session_data) do
    session_hour = extract_hour_from_timestamp(session_data.start_time)

    %{accumulator |
      total_sessions: accumulator.total_sessions + 1,
      total_session_duration_seconds:
        accumulator.total_session_duration_seconds + session_data.duration_seconds,
      total_pages_visited:
        accumulator.total_pages_visited + session_data.pages_visited,
      action_ocurrences:
        Enum.reduce(
          session_data.actions,
          accumulator.action_ocurrences,
          fn action, action_map ->
            Map.update(action_map, action, 1, &(&1 + 1)
          )
      end),
      sessions_by_hour:
        Map.update(accumulator.sessions_by_hour, session_hour, 1, &(&1 + 1))
    }
  end

  # ----------------------------------------------------------------------
  # VALIDATION AND PARSING
  # ----------------------------------------------------------------------

  @doc false
  # Validates that the ID is an integer and "nombre" exists
  defp validate_and_parse_user(user_map) do
    cond do
      !is_integer(Map.get(user_map, "id")) ->
        {:error, "User ID missing or invalid type"}

      !is_binary(Map.get(user_map, "nombre")) ->
        {:error, "User name missing for ID. #{Map.get(user_map, "id")}"}

      true ->
        {:ok, %{active: Map.get(user_map, "activo", false)}}
    end
  end

  @doc false
  # Validates that the session duration is positive
  defp validate_and_parse_session(session_map) do
    duration = Map.get(session_map, "duracion_segundos", 0)

    if is_integer(duration) and duration >= 0 do
      {:ok,
        %{
          start_time: Map.get(session_map, "inicio"),
          duration_seconds: duration,
          pages_visited: Map.get(session_map, "paginas_visitadas", 0),
          actions: Map.get(session_map, "acciones", [])
      }}
    else
      {:error, "Session duration negative or invalid for User: #{Map.get(session_map, "usuario_id")}"}
    end
  end

  # ----------------------------------------------------------------------
  # HELPERS
  # ----------------------------------------------------------------------

  defp extract_hour_from_timestamp(timestamp) do
    case String.split(timestamp, "T") do
      [_, time] ->
        time
        |> String.slice(0, 2)
        |> String.to_integer()

      _ -> 0
    end
  end

  # ----------------------------------------------------------------------
  # FINAL METRICS CALCULATION
  # ----------------------------------------------------------------------

  @doc false
  # Uses the accumulator data to calculate metrics and stores them in a map with
  # data that the Report module can convert into a string.
  defp build_final_metrics(accumulator) do
    average_session_duration_minutes =
      if accumulator.total_sessions > 0 do
        (accumulator.total_session_duration_seconds / accumulator.total_sessions) / 60
      else
        0.0
      end

    top_actions =
      accumulator.action_ocurrences
      |> Enum.sort_by(fn {_action, count} -> count end, :desc)
      |> Enum.take(5)
      |> Enum.map(fn {action, count} -> "#{action}: #{count}" end)

    peak_hour =
      if map_size(accumulator.sessions_by_hour) > 0 do
        {hour, _count} = Enum.max_by(accumulator.sessions_by_hour, fn {_hour, count} -> count end)

        "#{hour}:00"
      else
        "N/A"
      end

    %{
      total_users: accumulator.total_users,
      active_users: accumulator.active_users,
      active_percent: calculate_percentage(accumulator.active_users, accumulator.total_users),
      avg_session_duration: Float.round(average_session_duration_minutes, 2),
      total_pages_visited: accumulator.total_pages_visited,
      top_5_actions: top_actions,
      peak_hour: "#{peak_hour}",
      total_sessions: accumulator.total_sessions,
      errors_found: length(accumulator.data_errors),
      error_details: Enum.reverse(accumulator.data_errors)
    }
  end

  defp calculate_percentage(0, _total), do: 0
  defp calculate_percentage(part, total), do: Float.round((part / total) * 100, 2)
end
