defmodule FileProcessorWeb.MetricsLive do
  use FileProcessorWeb, :live_view

  @doc """
  Initializes the state. Sets the default mode to :sequential as per requirements.
  """
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:processing_started, false)
      |> assign(:all_done, false)
      |> assign(:mode, :sequential) # Step 2: Sequential by default [cite: 19, 20]
      |> assign(:stats, %{total: 0, processed: 0, errors: 0, current: 0})
      |> assign(:files, [])

    {:ok, socket}
  end

  @doc """
  Handles mode changes. Converting the string to an atom is vital for the
  HEEx template's conditional logic to work.
  """
  def handle_event("change_mode", %{"mode" => mode_str}, socket) do
    new_mode = String.to_atom(mode_str)
    # Debug: Check your terminal to see if the atom changes correctly
    IO.inspect(new_mode, label: "Current Processing Mode")
    {:noreply, assign(socket, mode: new_mode)}
  end

  @doc """
  Triggers the processing flow. In this stage, it uses the simulation logic.
  """
  def handle_event("start_processing", _params, socket) do
    send(self(), :run_simulation)
    {:noreply, assign(socket, processing_started: true, all_done: false, files: [], stats: %{total: 5, processed: 0, errors: 0, current: 0})}
  end

  @doc """
  Simulates file processing messages arriving via PubSub.
  """
  def handle_info(:run_simulation, socket) do
    for i <- 1..5 do
      Process.send_after(self(), {:file_processed, %{
        mode: socket.assigns.mode,
        name: "data_chunk_#{i}.csv",
        status: (if i == 3, do: :error, else: :ok),
        current: i,
        total: 5
      }}, i * 1000)
    end
    Process.send_after(self(), {:all_done, %{}}, 6000)
    {:noreply, socket}
  end

  @doc """
  Updates UI counters and file list in real-time[cite: 9, 26].
  """
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

  @doc """
  Finalizes the process and enables filters[cite: 30].
  """
  def handle_info({:all_done, _final_metrics}, socket) do
    {:noreply, assign(socket, all_done: true, processing_started: false)}
  end
end
