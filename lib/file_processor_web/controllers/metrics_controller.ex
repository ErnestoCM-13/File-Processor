defmodule FileProcessorWeb.MetricsController do
  use FileProcessorWeb, :controller

  def index(conn, %{"id" => id}) do
    # Aquí es donde el puente ocurre:
    # 1. Recuperamos el mapa usando el ID (cuando tu compañero tenga el Store listo)
    # Por ahora, usamos los "dummy data" que tenías en el mount para que no se rompa la vista.

    results = %{
      total_files: 10,
      processed_files: 9,
      failed_files: 4,
      success_rate: 60,
      performance: %{
        sequential: "0.0544 seconds",
        parallel: "0.0033 seconds",
        processes: 10,
        memory: "0.01 MB",
        improvement: "16.72 Times faster"
      },
      json_files: [
        %{name: "usuarios.json", total_objects: 150, top_domain: "gmail.com (85 users)", unique_roles: "Admin, Editor, Viewer", avg_age: 32.5},
        %{name: "config_backup.json", total_objects: 45, top_domain: "N/A", unique_roles: "System, Dev", avg_age: "N/A"}
      ]
    }

    render(conn, :index, results: results, id: id)
  end

  # Caso por si alguien entra a /metrics sin un ID
  def index(conn, _params) do
    redirect(conn, to: ~p"/")
  end
end
