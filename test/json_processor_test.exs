defmodule FileProcessor.JsonProcessorTest do
  use ExUnit.Case

  setup do
    %{
      valid_json: "data/valid/usuarios.json",
      error_json: "data/error/usuarios_sucio.json",
      malformed_json: "data/error/usuarios_malformado.json"
    }
  end

  describe "process/1" do
    test "returns a two-element tuple with :ok and a map", %{valid_json: valid_json} do
      assert {:ok, metrics} = FileProcessor.JsonProcessor.process(valid_json)
      assert is_map(metrics)
    end

    test "returns a map with expected keys", %{valid_json: valid_json} do
      {:ok, metrics} = FileProcessor.JsonProcessor.process(valid_json)
      expected_keys = [
        :total_users,
        :active_users,
        :active_percent,
        :avg_session_duration,
        :total_pages_visited,
        :top_5_actions,
        :peak_hour,
        :total_sessions,
        :errors_found,
        :error_details
      ]

      assert Enum.sort(Map.keys(metrics)) == Enum.sort(expected_keys)
    end

    test "returns metrics with the correct data type", %{valid_json: valid_json} do
      {:ok, metrics} = FileProcessor.JsonProcessor.process(valid_json)

      assert is_integer(metrics.total_users)
      assert is_integer(metrics.active_users)
      assert is_float(metrics.active_percent)
      assert is_float(metrics.avg_session_duration)
      assert is_integer(metrics.total_pages_visited)
      assert is_list(metrics.top_5_actions)
      assert is_binary(metrics.peak_hour)
      assert is_integer(metrics.total_sessions)
      assert is_integer(metrics.errors_found)
      assert is_list(metrics.error_details)
    end
  end

  describe "process/1 with valid files" do
    test "returns metrics with the exact expected values", %{valid_json: valid_json} do
      {:ok, metrics} = FileProcessor.JsonProcessor.process(valid_json)

      assert metrics.total_users == 10
      assert metrics.active_users == 7
      assert metrics.active_percent == 70
      assert metrics.avg_session_duration == 26.7
      assert metrics.total_pages_visited == 161
      assert metrics.top_5_actions == [
        "login: 10",
        "logout: 10",
        "ver_dashboard: 6",
        "buscar: 4",
        "ver_reportes: 4"
      ]
      assert metrics.peak_hour == "9:00"
      assert metrics.total_sessions == 10
      assert metrics.errors_found == 0
      assert metrics.error_details == []
    end
  end

  describe "process/1 with error files" do
    test "skip invalid JSON entries and collects their errors", %{error_json: error_json} do
      {:ok, metrics} = FileProcessor.JsonProcessor.process(error_json)

      assert metrics.total_users == 0
      assert metrics.active_users == 0
      assert metrics.active_percent == 0
      assert metrics.avg_session_duration == 0.0
      assert metrics.total_pages_visited == 0
      assert metrics.top_5_actions == []
      assert metrics.peak_hour == "N/A"
      assert metrics.total_sessions == 0
      assert metrics.errors_found == 4
      assert metrics.error_details == [
        "User ID missing or invalid type",
        "User name missing for ID. 2",
        "Session duration negative or invalid for User: 1",
        "Session duration negative or invalid for User: 2"
      ]
    end

    test "Handles a malformed JSON file and returns an error tuple", %{malformed_json: malformed_json} do
      assert {:error, reason} = FileProcessor.JsonProcessor.process(malformed_json)
      assert reason == "Malformed JSON file"
    end
  end
end
