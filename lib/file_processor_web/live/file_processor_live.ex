defmodule FileProcessorWeb.FileProcessorLive do
  use FileProcessorWeb, :live_view

  import FileProcessorWeb.DashboardComponents
  import FileProcessorWeb.UploadFormComponent
  import FileProcessorWeb.MetricsDashboardComponent
  import FileProcessorWeb.FileListComponent
  import FileProcessorWeb.SuccessToastComponent
  import FileProcessorWeb.ExecutiveSummaryComponent

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
      |> assign(:stats, %{total: 0, processed: 0, errors: 0, warnings: 0})
      |> assign(:files, [])
      |> assign(:total_rows, 0)
      |> assign(:current_filter, "all")
      |> assign(:expanded_file, nil)
      |> assign(:results_id, nil)
      # PREPARING: Empty state for the "Live Benchmark" race tracks
      |> assign(:benchmark_stats, %{sequential: %{processed: 0}, parallel: %{processed: 0}})
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
      |> assign(:files, [])
      |> assign(:stats, %{
        total: Enum.count(files),
        processed: 0,
        errors: 0,
        warnings: 0
      })}
  end

  def handle_event("toggle_error_details", %{"name" => name}, socket) do
    expanded =
      if socket.assigns.expanded_file == name,
        do: nil,
        else: name

    {:noreply, assign(socket, :expanded_file, expanded)}
  end

  def handle_event("set_filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, :current_filter, filter)}
  end

  def handle_event("reset_processor", _params, socket) do
    {:noreply,
      socket
      |> assign(:all_done, false)
      |> assign(:processing_started, false)
      |> assign(:files, [])
      |> assign(:total_rows, 0)
      |> assign(:stats, %{total: 0, processed: 0, errors: 0})}
  end

  # ------------------------
  # PUBSUB UPDATES
  # ------------------------

  def handle_info(%{event: "file_processed", payload: payload}, socket) do
    # FIX: Use an internal counter instead of payload.current to ensure we reach 100%
    new_processed_count = socket.assigns.stats.processed + 1

    current_errors = socket.assigns.stats.errors || 0
    current_warnings = socket.assigns.stats.warnings || 0

    # FIX: Separate stats into 3 states (ok, warning, error)
    {new_errors, new_warnings} = case payload.status do
      :error   -> {current_errors + 1, current_warnings}
      :warning -> {current_errors, current_warnings + 1}
      _        -> {current_errors, current_warnings}
    end

    # UPDATE: Benchmark tracks logic
    new_benchmark = if socket.assigns.mode == :benchmark do
      update_in(socket.assigns.benchmark_stats, [payload.mode, :processed], fn current -> current + 1 end)
    else
      socket.assigns.benchmark_stats
    end

    new_stats = %{
      total: payload.total,
      processed: new_processed_count,
      errors: new_errors,     # This MUST be the same key used in the card
      warnings: new_warnings  # We should add this too
    }

    file = %{
      name: payload.name,
      status: payload.status,
      # Now we pass the reason to the UI for the Details inspector
      reason: Map.get(payload, :reason, "Processed successfully."),
      detail: "Engine: #{payload.mode}"
    }

    {:noreply,
      socket
      |> assign(:stats, new_stats)
      |> assign(:benchmark_stats, new_benchmark)
      |> assign(:files, [file | socket.assigns.files])}
  end

  def handle_info(%{event: "all_done", payload: %{results: metrics_struct}}, socket) do
    metrics = Map.from_struct(metrics_struct)
    summary_map =
    if Map.has_key?(metrics, :executive_summary) and is_struct(metrics.executive_summary) do
      Map.from_struct(metrics.executive_summary)
    else
      metrics[:executive_summary] || %{}
    end

    total_files = summary_map[:successfully_processed_files] || 0
    results_id = :crypto.strong_rand_bytes(16) |> Base.encode16()
    FileProcessor.ResultsCache.put_processment_results(results_id, metrics)

    {:noreply,
      socket
      |> assign(:all_done, true)
      |> assign(:processing_started, true)
      |> assign(:total_rows, total_files)
      |> assign(:results_id, results_id)
      |> assign(:final_metrics, metrics)
      |> assign(:stats, socket.assigns.stats) # Refresh stats just in case
      |> push_event("refresh_counters", %{total: socket.assigns.stats.total})}
      rescue
      # 5. SAFETY NET: If something still fails, don't let the LiveView die
      e ->
        IO.inspect(e, label: "CRITICAL ERROR IN ALL_DONE")
        {:noreply, assign(socket, :all_done, true)}
  end
end
