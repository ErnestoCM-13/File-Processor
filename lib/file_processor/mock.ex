defmodule FileProcessor.Mock do
  @moduledoc """
  Simulates the File processor
  """

  def process_files(execution_mode, :list, files, runtime_config) do
    config = %{
      timeout: Map.get(runtime_config, :timeout) || 5000,
      max_workers: Map.get(runtime_config, :max_workers) || 10
    }

    IO.puts("Procesado")

    # Results map
    %{
      # --- OBLIGATORY KEYS ---
      process_mode: execution_mode,
      process_config: config,
      report: "Downloaded report content (Simulated)",

      log: [
        %{
          file: "sistema_corrupto.log",
          metrics: %{
            errors_found: 3,
            error_details: ["Invalid log format...", "Invalid log format...", "Invalid log format..."],
            level_distribution: ["ERROR: 33.3%", "FATAL: 33.3%", "INFO: 33.3%"],
            total_entries: 3,
            most_problematic_component: "DB (1 errors)",
            frequent_error_pattern: "Connection lost (1 ocurrences)",
            peak_log_hour: "14:00"
          },
          internal_errors: []
        }
      ],

      json: [
        %{
          file: "usuarios_sucio.json",
          metrics: %{
            errors_found: 4,
            error_details: ["User ID missing", "User name missing", "Session duration invalid", "Session duration invalid"],
            top_5_actions: [],
            total_users: 0,
            active_users: 0,
            active_percent: 0,
            avg_session_duration: 0.0,
            total_pages_visited: 0,
            total_sessions: 0,
            peak_hour: "N/A"
          },
          internal_errors: []
        }
      ],

      csv: [
        %{
          file: "ventas_corrupto.csv",
          metrics: %{
            errors_found: 8,
            error_details: ["line 2: Invalid price", "line 3: Invalid quantity"],
            total_sales: 1927.95,
            unique_products: 3,
            top_product: "Tablet Samsung (3 units)",
            top_category: "Tablets ($1619.97)",
            average_discount: 10.0,
            date_range: "2024-03-01 to 2024-03-05",
            processed_lines: 3
          },
          internal_errors: []
        }
      ],

      executive_summary: %{
        total_files_attempted: 4,
        successfully_processed_files: 3,
        files_with_internal_errors: 1,
        success_rate_percentage: 65
      },

      errors: [%{reason: "Malformed JSON file", file: "usuarios_malformado.json"}],

      # --- ADITIONAL KEYS (Performance) ---
      performance: %{
        processes: config.max_workers,
        improvement: 4.85,
        sequential_time: 0.023916,
        parallel_time: 0.004934,
        memory_max: 0.02
      },
      processes_used: config.max_workers
    }
  end
end
