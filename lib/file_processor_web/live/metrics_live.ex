defmodule FileProcessorWeb.MetricsLive do
  use FileProcessorWeb, :live_view

  @doc """
  Initializes the dashboard state and configures allowed file uploads.
  """
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:processing_started, false)
      |> assign(:all_done, false)
      |> assign(:mode, :sequential)
      |> assign(:stats, %{total: 0, processed: 0, errors: 0, current: 0})
      |> assign(:files, [])
      |> allow_upload(:files_input,
        accept: ~w(.csv .json .log),
        max_entries: 20,
        max_file_size: 10_000_000
      )

    {:ok, socket}
  end

  # --- CALLBACKS: handle_event ---
  # These handle interactions from the browser (clicks, changes, etc.)

  @doc """
  Handles all UI events including mode changes, file validation, and processing triggers.
  """
  def handle_event("validate", %{"mode" => mode_str}, socket) do
    {:noreply, assign(socket, mode: String.to_atom(mode_str))}
  end

  def handle_event("validate", _params, socket) do
    # Required for LiveView to detect file selection
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :files_input, ref)}
  end

  def handle_event("start_processing", _params, socket) do
    file_names = consume_uploaded_entries(socket, :files_input, fn _meta, entry ->
      {:ok, entry.client_name}
    end)

    if Enum.empty?(file_names) do
      {:noreply, put_flash(socket, :error, "No files uploaded")}
    else
      total_files = Enum.count(file_names)
      send(self(), {:run_simulation, file_names})

      {:noreply,
       socket
       |> assign(:processing_started, true)
       |> assign(:all_done, false)
       |> assign(:files, [])
       |> assign(:stats, %{total: total_files, processed: 0, errors: 0, current: 0})}
    end
  end

  # --- CALLBACKS: handle_info ---
  # These handle internal messages (simulation, PubSub-like events)

  @doc """
  Handles simulation messages and real-time updates from the processing engine.
  """
  def handle_info({:run_simulation, file_names}, socket) do
    total = Enum.count(file_names)

    file_names
    |> Enum.with_index(1)
    |> Enum.each(fn {name, index} ->
      Process.send_after(self(), {:file_processed, %{
        mode: socket.assigns.mode,
        name: name,
        status: (if rem(index, 3) == 0, do: :error, else: :ok),
        current: index,
        total: total
      }}, index * 1000)
    end)

    Process.send_after(self(), {:all_done, %{}}, (total + 1) * 1000)
    {:noreply, socket}
  end

  def handle_info({:file_processed, data}, socket) do
    new_errors = if data.status in [:warning, :error], do: socket.assigns.stats.errors + 1, else: socket.assigns.stats.errors

    new_stats = %{
      socket.assigns.stats |
      processed: data.current,
      total: data.total,
      errors: new_errors
    }

    {:noreply, assign(socket, stats: new_stats, files: [data | socket.assigns.files])}
  end

  def handle_info({:all_done, _final_metrics}, socket) do
    # Placeholder for ResultsCache persistence
    {:noreply, assign(socket, all_done: true, processing_started: false)}
  end

  # --- HELPERS ---

  @doc """
  Formats incoming data from the processing engine.
  Ensures the frontend always receives the expected keys.
  """
  defp format_process_result(data) do
    %{
      name: Map.get(data, :name, "Unknown File"),
      status: Map.get(data, :status, :ok),
      current: Map.get(data, :current, 0),
      total: Map.get(data, :total, 1),
      size: Map.get(data, :size, "0 KB"),
      timestamp: Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")
    }
  end
end
