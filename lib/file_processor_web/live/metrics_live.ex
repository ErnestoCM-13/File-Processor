defmodule FileProcessorWeb.MetricsLive do
  use FileProcessorWeb, :live_view

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

  @doc """
  Starts the concurrent processing engine using Task.async_stream.
  It uses the user-defined concurrency (workers) and timeout.
  """

  def handle_event("start_processing", params, socket) do
    # 1. Parse and validate workers
    workers = String.to_integer(Map.get(params, "workers", "4"))
    timeout = String.to_integer(Map.get(params, "timeout", "5000"))

    cond do
      # Check if there are no files selected
      Enum.empty?(socket.assigns.uploads.files_input.entries) ->
        {:noreply, put_flash(socket, :error, "No files detected. Please upload at least one file.")}

      # Security check: Max 10 workers allowed
      workers > 10 ->
        {:noreply, put_flash(socket, :error, "Security limit exceeded: Maximum 10 workers allowed.")}

      # Security check: Min 1 worker required
      workers < 1 ->
        {:noreply, put_flash(socket, :error, "At least 1 worker is required for analysis.")}

      true ->
        # Proceed with file consumption
        file_data = consume_uploaded_entries(socket, :files_input, fn _meta, entry ->
          {:ok, %{name: entry.client_name, size: format_size(entry.client_size)}}
        end)

        # Trigger the engine
        send(self(), {:process_batch, file_data, %{workers: workers, timeout: timeout}})

        {:noreply,
        socket
        |> assign(:processing_started, true)
        |> assign(:stats, %{total: Enum.count(file_data), processed: 0, errors: 0, current: 0})}
      end
    end

    # Helper to format size in a human-readable way
    defp format_size(bytes) do
      cond do
        bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 2)} MB"
        bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 2)} KB"
        true -> "#{bytes} B"
      end
    end

  # --- CALLBACKS: handle_info ---
  # These handle internal messages (simulation, PubSub-like events)

  @doc """
  Handles simulation messages and real-time updates from the processing engine.
  Manages the parallel execution of file analysis.
  It respects the concurrency limit and sends updates to the UI.
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
    formatted_data = format_process_result(data)

    # Logic to update stats based on formatted_data
    new_errors = if formatted_data.status == :error, do: socket.assigns.stats.errors + 1, else: socket.assigns.stats.errors

    new_stats = %{
      socket.assigns.stats |
      processed: formatted_data.current,
      total: formatted_data.total,
      errors: new_errors
    }

    {:noreply, assign(socket, stats: new_stats, files: [formatted_data | socket.assigns.files])}
  end

  def handle_info({:all_done, _final_metrics}, socket) do
    # Placeholder for ResultsCache persistence
    {:noreply, assign(socket, all_done: true, processing_started: false)}
  end


  def handle_info({:process_batch, file_list, config}, socket) do
    total = Enum.count(file_list)
    parent = self() # We need the LiveView PID for the tasks to send messages back

    # Start a separate process so we don't block the LiveView while waiting for the stream
    Task.start(fn ->
      file_list
      |> Enum.with_index(1)
      |> Task.async_stream(
        fn {file, index} ->
          # SIMULATION: Replace this with real file parsing later
          Process.sleep(1000)

          # Send update to PubSub or self
          send(parent, {:file_processed, %{
            name: file.name,
            status: (if rem(index, 4) == 0, do: :error, else: :ok),
            current: index,
            total: total
          }})
        end,
        max_concurrency: config.workers,
        timeout: config.timeout,
        on_timeout: :kill_task # If it hangs, kill it to free the worker
      )
      |> Stream.run() # This triggers the execution

      send(parent, {:all_done, %{}})
    end)

    {:noreply, socket}
  end

  # --- HELPERS ---

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
