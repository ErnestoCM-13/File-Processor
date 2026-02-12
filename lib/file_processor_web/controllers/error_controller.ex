# lib/file_processor_web/controllers/error_controller.ex
defmodule FileProcessorWeb.ErrorController do
  use FileProcessorWeb, :controller

  def index(conn, _params) do
    # Mock data for errors found during processing
    errors = [
      %{file: "ventas_marzo.csv", line: 45, reason: "Invalid date format", snippet: "2024-13-01,Product_A,50.0"},
      %{file: "config.json", line: 12, reason: "Unexpected token", snippet: "\"timeout\": 5000,, \"retry\": true"},
      %{file: "system.log", line: 890, reason: "Memory overflow simulation", snippet: "CRITICAL: Out of memory at 0x89FF"}
    ]

    render(conn, :index, errors: errors)
  end
end
