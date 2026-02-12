# lib/file_processor_web/controllers/error_controller.ex
defmodule FileProcessorWeb.ErrorController do
  use FileProcessorWeb, :controller

  def index(conn, _params) do
    # Mock data structured to match the new Figma design
    errors = [
      %{type: :critical, file: "usuarios_malformado.json", msg: "Malformed JSON file"},
      %{type: :critical, file: "invalid_file_type.txt", msg: "Unsupported file type, expected files with extension .csv, .json or .log"},
      %{type: :warning, file: "ventas_corrupto.csv", details: [
        "line 2: Invalid price", "line 3: Invalid quantity", "line 5: Corrupt line (missing columns)"
      ]},
      %{type: :warning, file: "usuarios_sucio.json", details: [
        "User ID missing or invalid type", "Session duration negative or invalid for User: 1"
      ]}
    ]

    # Calculate counts for the top cards
    counts = %{total: 5, critical: 2, invalid: 3}

    render(conn, :index, errors: errors, counts: counts)
  end
end
