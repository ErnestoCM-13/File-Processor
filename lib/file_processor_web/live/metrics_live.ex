# lib/file_processor_web/live/metrics_live.ex
defmodule FileProcessorWeb.MetricsLive do
  use FileProcessorWeb, :live_view

  def mount(_params, _session, socket) do
    # Initial state with dummy data matching the Figma design
        {:ok, assign(socket,
          page_title: "Metrics Report",
          total_files: 10,
          processed_files: 9,
          failed_files: 4,
          success_rate: 60,
          # Performance comparison data
          performance: %{
            sequential: "0.0544 seconds",
            parallel: "0.0033 seconds",
            processes: 10,
            memory: "0.01 MB",
            improvement: "16.72 Times faster"
          },
          json_files: [
                %{
                  name: "usuarios.json",
                  total_objects: 150,
                  top_domain: "gmail.com (85 users)",
                  unique_roles: "Admin, Editor, Viewer",
                  avg_age: 32.5
                },
                %{
                  name: "config_backup.json",
                  total_objects: 45,
                  top_domain: "N/A",
                  unique_roles: "System, Dev",
                  avg_age: "N/A"
                }
              ]
    )}
  end
end
