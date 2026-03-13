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

  @doc """
  Triggers the file processing engine.
  Documentation: Instead of manual tasks, we invoke the Parallel module
  which will handle broadcasting via Notifier.
  """
  @doc """
  Triggers the processing engine by ensuring file persistence
  and invoking the Parallel coordinator.
  """
  def handle_event("start_processing", params, socket) do
    # 1. Consume and persist uploaded files to prevent 'no such file' errors
    file_data = consume_uploaded_entries(socket, :files_input, fn %{path: path}, entry ->
      # Create a persistent destination path in the system temp directory
      dest = Path.join(System.tmp_dir!(), entry.client_name)

      # Copy file to destination so it remains available for the background workers
      File.cp!(path, dest)

      # Return the format expected by Parallel.run/3: {path, name}
      {:ok, {dest, entry.client_name}}
    end)

    # 2. Extract configuration from UI parameters
    workers = String.to_integer(Map.get(params, "workers", "4"))
    timeout = String.to_integer(Map.get(params, "timeout", "5000"))

    # 3. Invoke the backend logic from your teammate's branch
    # We use Task.start to prevent blocking the LiveView process
    Task.start(fn ->
      FileProcessor.Execution.Parallel.run(
        file_data,
        %FileProcessor.Core.Metrics{},
        %{max_workers: workers, timeout: timeout}
      )
    end)

    {:noreply,
    socket
    |> assign(:processing_started, true)
    |> assign(:files, []) # Clear list for new results
    |> assign(:stats, %{total: Enum.count(file_data), processed: 0, errors: 0, current: 0})}
  end
  
  def handle_event("toggle_error_details", %{"name" => name}, socket) do
    new_expanded = if socket.assigns.expanded_file == name, do: nil, else: name
    {:noreply, assign(socket, expanded_file: new_expanded)}
  end

  @doc """
  Updates the UI filter state when a pill is clicked.
  """
  def handle_event("set_filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, :current_filter, filter)}
  end

    #Documentation: Clears all accumulated metrics, file lists, and row counters.

  def handle_event("reset_processor", _params, socket) do
    {:noreply,
    socket
    |> assign(:all_done, false)
    |> assign(:processing_started, false)
    |> assign(:files, []) # Clears the file list
    |> assign(:total_rows, 0) # RESET: The row counter goes back to zero
    |> assign(:stats, %{total: 0, processed: 0, errors: 0, current: 0})}
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

  @doc """
  Handles the real-time broadcast from the Parallel Coordinator.
  Documentation: Matches the exact structure sent by Notifier.broadcast_file_progress.
  """
  def handle_info(%{event: "file_processed", payload: payload}, socket) do
    # Payload contains: %{mode: _, name: _, status: _, current: _, total: _}

    # 1. Update global stats
    new_errors = if payload.status == :error, do: socket.assigns.stats.errors + 1, else: socket.assigns.stats.errors

    new_stats = %{
      socket.assigns.stats |
      processed: payload.current,
      total: payload.total,
      errors: new_errors
    }

    # 2. Add file to the list for the UI
    new_file = %{
      name: payload.name,
      status: payload.status,
      detail: "Processed via #{payload.mode}", # Using the mode sent by the back
      timestamp: Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")
    }

    {:noreply,
    socket
    |> assign(stats: new_stats)
    |> assign(files: [new_file | socket.assigns.files])}
  end

  @doc """
  Handles the completion event.
  """
  def handle_info(%{event: "all_done", payload: _payload}, socket) do
    {:noreply, assign(socket, all_done: true)}
  end


  def handle_info({:process_batch, file_list, config}, socket) do
    total = Enum.count(file_list)
    parent = self()

    Task.start(fn ->
      file_list
      |> Enum.with_index(1)
      |> Task.async_stream(
        fn {%{name: name, path: path}, index} ->
          # REAL ANALYSIS: No more random status!
          {status, detail} = parse_file_content(path, name)

          send(parent, {:file_processed, %{
            name: name,
            status: status,
            detail: detail, # We'll show this in the UI
            current: index,
            total: total
          }})
        end,
        max_concurrency: config.workers,
        timeout: config.timeout
      )
      |> Stream.run()

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

  # --- PARSING LOGIC ---

  @doc """
  Main entry point for file analysis.
  Routes the file to the correct parser based on extension.
  """
  defp parse_file_content(path, name) do
    extension = path |> Path.extname() |> String.downcase()

    case extension do
      ".csv" -> parse_csv(path)
      ".json" -> parse_json(path)
      ".log" -> parse_log(path)
      _ -> {:error, "Unsupported format"}
    end
  end

  defp parse_csv(path) do
    # Counting lines in a CSV as a basic metric
    line_count = path |> File.stream!() |> Enum.count()
    {:ok, "Rows detected: #{line_count}"}
  end

  defp parse_log(path) do
    # Searching for the word "ERROR" in the log file
    error_count =
      path
      |> File.stream!()
      |> Enum.count(&(String.contains?(&1, "ERROR") or String.contains?(&1, "FAIL")))

    if error_count > 0,
      do: {:warning, "Found #{error_count} critical events"},
      else: {:ok, "No errors found"}
  end

  defp parse_json(path) do
    # Basic validation: is it a valid JSON?
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, _data} -> {:ok, "Valid JSON structure"}
          {:error, _} -> {:error, "Invalid JSON syntax"}
        end
      {:error, _} -> {:error, "Read error"}
    end
  end
end
