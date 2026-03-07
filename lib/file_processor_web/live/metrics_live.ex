defmodule FileProcessorWeb.MetricsLive do
  use FileProcessorWeb, :live_view

  @doc """
  Initializes the socket state for the unified dashboard.
  """
  def mount(_params, _session, socket) do
    # Initial state based on the agreed flow
    socket =
      socket
      |> assign(:processing_started, false)
      |> assign(:all_done, false)
      |> assign(:mode, :sequential) # Step 2: Sequential by default
      |> assign(:stats, %{total: 0, processed: 0, errors: 0, current: 0})
      |> assign(:files, [])

    {:ok, socket}
  end

  @doc """
  Handles the mode selection (Sequential, Parallel, Benchmark).
  """
  def handle_event("change_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, mode: String.to_atom(mode))}
  end

  @doc """
  Handles the incoming messages from the processor for each file.
  """
  def handle_info({:file_processed, data}, socket) do
    # Step 5: Update counters and file list in real-time
    new_errors = if data.status in [:warning, :error], do: socket.assigns.stats.errors + 1, else: socket.assigns.stats.errors

    new_stats = %{
      socket.assigns.stats |
      processed: data.current,
      total: data.total,
      errors: new_errors
    }

    # Updating the list to show files as they are processed
    {:noreply, assign(socket, stats: new_stats, files: [data | socket.assigns.files])}
  end

  @doc """
  Handles the final message once all files are processed.
  """
  def handle_info({:all_done, _final_metrics}, socket) do
    # Step 7: Replace skeletons with metrics and enable UI elements
    {:noreply, assign(socket, all_done: true, processing_started: false)}
  end
end
