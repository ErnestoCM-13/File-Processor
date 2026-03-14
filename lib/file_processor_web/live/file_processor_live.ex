defmodule FileProcessorWeb.FileProcessorLive do
  use FileProcessorWeb, :live_view

  import FileProcessorWeb.DashboardComponents
  import FileProcessorWeb.UploadFormComponent
  import FileProcessorWeb.MetricsDashboardComponent
  import FileProcessorWeb.FileListComponent
  import FileProcessorWeb.SuccessToastComponent

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
      |> assign(:mode, :sequential)
      |> assign(:stats, %{total: 0, processed: 0, errors: 0})
      |> assign(:files, [])
      |> assign(:total_rows, 0)
      |> assign(:current_filter, "all")
      |> assign(:expanded_file, nil)
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
      |> assign(:files, [])
      |> assign(:stats, %{
        total: Enum.count(files),
        processed: 0,
        errors: 0
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
    errors =
      if payload.status == :error,
        do: socket.assigns.stats.errors + 1,
        else: socket.assigns.stats.errors

    stats = %{
      total: payload.total,
      processed: payload.current,
      errors: errors
    }

    file = %{
      name: payload.name,
      status: payload.status,
      detail: "Processed via #{payload.mode}"
    }

    {:noreply,
      socket
      |> assign(:stats, stats)
      |> assign(:files, [file | socket.assigns.files])}
  end

  def handle_info(%{event: "all_done", payload: %{results: metrics}}, socket) do
    results_id = :crypto.strong_rand_bytes(16) |> Base.encode16()

    FileProcessor.ResultsCache.put_processment_results(results_id, metrics)

    {:noreply,
      socket
      |> assign(:results_id, results_id)
      |> assign(:all_done, true)
      |> assign(:final_metrics, metrics)}
  end
end
