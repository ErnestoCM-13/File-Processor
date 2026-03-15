defmodule FileProcessorWeb.FileProcessorLive do
  use FileProcessorWeb, :live_view

  import FileProcessorWeb.DashboardComponents
  import FileProcessorWeb.UploadFormComponent
  import FileProcessorWeb.MetricsDashboardComponent
  import FileProcessorWeb.FileListComponent
  import FileProcessorWeb.SuccessToastComponent
  import FileProcessorWeb.ExecutiveSummaryComponent

  alias FileProcessor.ResultsCache

  @initial_stats %{
    sequential: %{total: 0, processed: 0, errors: 0, warnings: 0},
    parallel: %{total: 0, processed: 0, errors: 0, warnings: 0}
  }

  @doc """
  Initializes the dashboard state and configures allowed file uploads.
  """
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(FileProcessor.PubSub, "processor_updates")
    end

    socket =
      socket
      |> assign(:processing_started, false)
      |> assign(:all_done, false)
      |> assign(:final_metrics, nil)
      |> assign(:mode, :sequential)
      |> assign(:stats, @initial_stats)
      |> stream(:files_stream, [])
      |> assign(:total_rows, 0)
      |> assign(:current_filter, "all")
      |> assign(:expanded_error_file, nil)
      |> assign(:current_error_details, nil)
      |> assign(:results_id, nil)
      |> allow_upload(:files_input,
        accept: ~w(.csv .json .log),
        max_entries: 20,
        max_file_size: 10_000_000
      )

    {:ok, socket}
  end

  # ------------------------
  # EVENTS
  # ------------------------

  def handle_event("validate", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :mode, String.to_atom(mode))}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :files_input, ref)}
  end

  def handle_event("start_processing", params, socket) do
    files =
      consume_uploaded_entries(socket, :files_input, fn %{path: path}, entry ->
        dest = Path.join(System.tmp_dir!(), entry.client_name)
        File.cp!(path, dest)
        {:ok, {dest, entry.client_name}}
      end)

    execution_mode = socket.assigns.mode
    source_type = :list
    config = %{
      max_workers: String.to_integer(Map.get(params, "workers", "4")),
      timeout: String.to_integer(Map.get(params, "timeout", "5000"))
    }

    Task.start(fn ->
      FileProcessor.process_files(execution_mode, source_type, files, config)
    end)

    {:noreply,
      socket
      |> assign(:processing_started, true)
      |> assign(:all_done, false)
      |> assign(:current_filter, "all") # Ensure we are seeing "All" when starting
      |> stream(:files_stream, [], reset: true)
      |> assign(:stats,
        %{sequential: %{total: Enum.count(files), processed: 0, errors: 0, warnings: 0},
          parallel: %{total: Enum.count(files), processed: 0, errors: 0, warnings: 0}})
    }
  end

  def handle_event("toggle_error_details", %{"name" => name}, socket) do
      results_id = socket.assigns.results_id
      metrics = ResultsCache.get_processment_results(results_id)

      is_error = Enum.any?(metrics.errors || [], fn e -> e.file == name end)
      status = if is_error, do: :error, else: :warning

      if socket.assigns.expanded_error_file == name do
        # --- LOGIC TO CLOSE ---
        file = %{id: name, name: name, status: status, detail: "Details closed"}

        {:noreply,
         socket
         |> assign(expanded_error_file: nil, current_error_details: nil)
         |> stream_insert(:files_stream, file)}
      else
        # --- LOGIC TO OPEN ---
        details =
          if is_error do
            Enum.find(metrics.errors, fn e -> e.file == name end).reason
          else
            ext = name |> Path.extname() |> String.trim_leading(".") |> String.to_atom()
            metrics
            |> Map.get(ext, [])
            |> Enum.find(%{}, fn f -> f.file == name end)
            |> get_in([:metrics, :error_details])
          end

        file = %{id: name, name: name, status: status, detail: "Viewing details"}

        {:noreply,
         socket
         |> assign(expanded_error_file: name, current_error_details: details)
         |> stream_insert(:files_stream, file)}
      end
  end

  def handle_event("set_filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, :current_filter, filter)}
  end

  def handle_event("reset_processor", _params, socket) do
    {:noreply,
      socket
      |> assign(:all_done, false)
      |> assign(:processing_started, false)
      |> assign(:current_filter, "all") # Reset filter to default
      |> assign(:files, [])
      |> assign(:total_rows, 0)
      |> assign(:stats, @initial_stats)
    }
  end

  # ------------------------
  # PUBSUB UPDATES
  # ------------------------

  def handle_info(%{event: "file_processed", payload: payload}, socket) do
      new_stats = update_in(socket.assigns.stats, [payload.mode], fn current ->
        %{current |
          processed: current.processed + 1,
          errors: if(payload.status == :error, do: current.errors + 1, else: current.errors),
          warnings: if(payload.status == :warning, do: current.warnings + 1, else: current.warnings)
        }
      end)

      file = %{
        id: payload.name,
        name: payload.name,
        status: payload.status,
        reason: Map.get(payload, :reason, "OK"),
        detail: "Engine: #{payload.mode}"
      }

      {:noreply,
       socket
       |> assign(:stats, new_stats)
       |> stream_insert(:files_stream, file)}
  end


  def handle_info(%{event: "all_done", payload: %{results: metrics_struct}}, socket) do
    metrics = Map.from_struct(metrics_struct)

    summary_map =
    if Map.has_key?(metrics, :executive_summary) and is_struct(metrics.executive_summary) do
      Map.from_struct(metrics.executive_summary)
    else
      metrics[:executive_summary] || %{}
    end

    current_mode =
      if socket.assigns.mode == :sequential do
        :sequential
      else
        :parallel
      end

    total_for_js = socket.assigns.stats[current_mode].total
    total_files = summary_map[:successfully_processed_files] || 0
    results_id = :crypto.strong_rand_bytes(16) |> Base.encode16()

    ResultsCache.put_processment_results(results_id, metrics)

    {:noreply,
      socket
      |> assign(:all_done, true)
      |> assign(:processing_started, true)
      |> assign(:total_rows, total_files)
      |> assign(:results_id, results_id)
      |> assign(:final_metrics, metrics)
      |> assign(:stats, socket.assigns.stats) # Refresh stats just in case
      |> push_event("refresh_counters", %{total: total_for_js})}
      rescue
      # 5. SAFETY NET: If something still fails, don't let the LiveView die
      e ->
        IO.inspect(e, label: "CRITICAL ERROR IN ALL_DONE")
        {:noreply, assign(socket, :all_done, true)}
  end
end
