defmodule FileProcessorWeb.ProcessorLive do
  use FileProcessorWeb, :live_view

  # Al cargar la página, definimos el estado inicial
  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      page_title: "File Processor",
      mode: "sequential", # Modo seleccionado por defecto
      workers: 4,
      timeout: 4
    )}
  end

  # Esta función captura el clic en los modos de procesamiento
  def handle_event("select-mode", %{"mode" => selected_mode}, socket) do
    {:noreply, assign(socket, mode: selected_mode)}
  end

  # Aquí manejaremos el inicio del procesamiento después
  def handle_event("start-processing", _params, socket) do
    # Por ahora solo mandamos un log
    IO.puts("Iniciando procesamiento en modo: #{socket.assigns.mode}")
    {:noreply, socket}
  end
end
