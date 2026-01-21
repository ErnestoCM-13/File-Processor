defmodule FileProcessor.JsonProcessorTest do
  use ExUnit.Case

  setup do
    %{
      valid_json: "data/valid/usuarios.json",
      error_json: "data/error/usuarios_sucio.json"
    }
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
  end
end
