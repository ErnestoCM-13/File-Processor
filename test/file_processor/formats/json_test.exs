defmodule FileProcessor.Formats.JsonTest do
  use ExUnit.Case, async: true

  alias FileProcessor.Formats.Json

  @valid_json "data/valid/usuarios.json"
  @json_with_errors "data/error/usuarios_sucio.json"
  @json_malformed "data/error/usuarios_malformado.json"

  # ----------------------------------------------------------------------
  # TESTS
  # ----------------------------------------------------------------------

  describe "process/1" do
    test "processes a fully valid JSON correctly" do
      {:ok, metrics} = Json.process(@valid_json)

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

    test "processes JSON with user/session errors correctly" do
      {:ok, metrics} = Json.process(@json_with_errors)

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

    test "returns error for malformed JSON file" do
      assert {:error, "Malformed JSON file"} = Json.process(@json_malformed)
    end
  end
end
