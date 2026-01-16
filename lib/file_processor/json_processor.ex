defmodule FileProcessor.JsonProcessor do
  @moduledoc """
  Specialized processor for JSON files, delegated by `FileProcessor`.
  Extracts data and calculates metrics using `Jason`.
  Calculated metrics:
  - total users
  - active percent
  - average session duration
  - total pages visited
  - top 5 actions
  - peak hour
  - total sessions
  """

  @doc """
  Entry point for the module.
  Reads and decodes a JSON file using `Jason`, then initiates processing for both users and sessions.

  ## Data flow
  1. File reading.
  2. Decoding strings into Elixir maps using Jason.
  3. Data accumulation of the "users" list.
  4. Data accumulation of the "sessions" list.
  5. Metrics calculation.

  Retorns `{:ok, metrics}` or `{:error, reason}` if the file is corrupted.
  """
  def process(path) do
    with {:ok, content} <- File.read(path),
         {:ok, decoded_data} <- Jason.decode(content) do

      metrics =
        set_initial_accumulator()
        |> process_users(Map.get(decoded_data, "usuarios", []))
        |> process_sessions(Map.get(decoded_data, "sesiones", []))
        |> finalize_metrics()

      {:ok, metrics}
    else
      {:error, %Jason.DecodeError{}} -> {:error, "Malformed JSON file"}
      {:error, reason} -> {:error, "Read error: #{reason}"}
    end
  end

  @doc false
  # Initializes the data accumulator with default values for JSON metrics.
  defp set_initial_accumulator() do
    %{
      total_users: 0,
      active_users: 0,
      inactive_users: 0,
      total_sessions: 0,
      total_duration: 0,
      total_pages: 0,
      actions_map: %{}, # %{"click" => 5, "login" => 2}
      hours_map: %{},    # %{hour => sesions}
      data_errors: []
    }
  end

  # --- RECURSIVE LOGIC ---

  @doc false
  # Iterates over the "usuarios" list, validating them using the validate_user/1 function.
  defp process_users(accumulator, []), do: accumulator
  defp process_users(accumulator, [head_user | tail]) do
    new_accumulator =
      case validate_user(head_user) do
        {:ok, user_data} -> update_user_metrics(accumulator, user_data)

        {:error, message} -> Map.update!(accumulator, :data_errors, &([message | &1]))
      end

    process_users(new_accumulator, tail)
  end

  @doc false
  # Updates the accumulator data with information from a successfully parsed user.
  defp update_user_metrics(accumulator, user_data) do
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

  @doc false
  # Iterates over the "sesiones" list, validating them using the validate_session/1 function.
  defp process_sessions(accumulator, []), do: accumulator
  defp process_sessions(accumulator, [head_sesion | tail]) do
    new_accumulator =
      case validate_session(head_sesion) do
        {:ok, session_data} -> update_session_metrics(accumulator, session_data)

        {:error, message} -> Map.update!(accumulator, :data_errors, &([message | &1]))
      end

    process_sessions(new_accumulator, tail)
  end

  @doc false
  # Updates the accumulator data with information from a successfully parsed session.
  defp update_session_metrics(accumulator, session_data) do
    hour = extract_hour(session_data.start_time)

    %{accumulator |
      total_sessions: accumulator.total_sessions + 1,
      total_duration: accumulator.total_duration + session_data.duration_seconds,
      total_pages: accumulator.total_pages + session_data.pages_visited,
      actions_map: Enum.reduce(session_data.actions, accumulator.actions_map, fn action, acc ->
        Map.update(acc, action, 1, &(&1 + 1))
      end),
      hours_map: Map.update(accumulator.hours_map, hour, 1, &(&1 + 1))
    }
  end

  # --- VALIDATION ---

  @doc false
  # Validates that the ID is an integer and "nombre" exists
  defp validate_user(user) do
    cond do
      !is_integer(Map.get(user, "id")) -> {:error, "User ID missing or invalid type"}
      !is_binary(Map.get(user, "nombre")) -> {:error, "User name missing for ID. #{Map.get(user, "id")}"}
      true -> {:ok, %{active: Map.get(user, "activo", false)}}
    end
  end

  @doc false
  # Validates that the session duration is positive
  defp validate_session(session) do
    duration = Map.get(session, "duracion_segundos", 0)
    if is_integer(duration) and duration >= 0 do
      {:ok, %{
        start_time: Map.get(session, "inicio"),
        duration_seconds: duration,
        pages_visited: Map.get(session, "paginas_visitadas", 0),
        actions: Map.get(session, "acciones", [])
      }}
    else
      {:error, "Session duration negative or invalid for User: #{Map.get(session, "usuario_id")}"}
    end
  end

  # --- HELPERS ---

  defp extract_hour(timestamp) do
    case String.split(timestamp, "T") do
      [_, time] -> time |> String.slice(0, 2) |> String.to_integer()
      _ -> 0
    end
  end

  # --- METRICS CALCULATION ---

  @doc false
  # Uses the accumulator data to calculate metrics and stores them in a map with
  # data that the Report module can convert into a string.
  defp finalize_metrics(accumulator) do
    avg_duration =
      if accumulator.total_sessions > 0 do
        (accumulator.total_duration / accumulator.total_sessions) / 60
      else
        0.0
      end

    top_actions =
      accumulator.actions_map
      |> Enum.sort_by(fn {_action, count} -> count end, :desc)
      |> Enum.take(5)
      |> Enum.map(fn {action, count} -> "#{action}: #{count}" end)

    peak_hour =
      if map_size(accumulator.hours_map) > 0 do
        {hour, _count} = Enum.max_by(accumulator.hours_map, fn {_hour, count} -> count end)
        "#{hour}:00"
      else
        "N/A"
      end

    %{
      total_users: accumulator.total_users,
      active_users: accumulator.active_users,
      active_percent: calculate_percent(accumulator.active_users, accumulator.total_users),
      avg_session_duration: Float.round(avg_duration, 2),
      total_pages_visited: accumulator.total_pages,
      top_5_actions: top_actions,
      peak_hour: "#{peak_hour}:00",
      total_sessions: accumulator.total_sessions,
      errors_found: length(accumulator.data_errors),
      error_details: Enum.reverse(accumulator.data_errors)
    }
  end

  defp calculate_percent(0, _), do: 0
  defp calculate_percent(part, total), do: Float.round((part / total) * 100, 2)
end
