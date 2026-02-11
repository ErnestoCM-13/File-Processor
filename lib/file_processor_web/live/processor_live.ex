defmodule FileProcessorWeb.ProcessorLive do
  use FileProcessorWeb, :live_view


  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "File Processor",
       mode: "sequential",
       loading: false,
       workers: 4,
       timeout: 4
     )
     # Upload files
     |> allow_upload(:files,
       accept: ~w(.csv .json .log),
       max_entries: 10,
       auto_upload: true
     )}
  end

  # captures click
  def handle_event("select-mode", %{"mode" => selected_mode}, socket) do
    {:noreply, assign(socket, mode: selected_mode)}
  end

  # handle the uploading process
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :files, ref)}
  end

  # Process handle
  def handle_event("start-processing", _params, socket) do
    socket = assign(socket, loading: true)

      consume_uploaded_entries(socket, :files, fn %{path: path}, entry ->
        dest = Path.join("priv/static/uploads", entry.client_name)
        File.cp!(path, dest)
        {:ok, dest}
      end)

      :timer.sleep(2000)

      {:noreply, assign(socket, loading: false)}
  end
end
