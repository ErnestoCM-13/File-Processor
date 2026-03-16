defmodule FileProcessorWeb.SuccessToastComponent do
  use Phoenix.Component

  def success_toast(assigns) do
    ~H"""
    <div
      :if={@show_toast}
      id="success-toast"
      class="fixed top-8 right-8 z-50 flex items-center gap-4 p-4 bg-white border border-gray-100 rounded-2xl shadow-[0_20px_50px_rgba(0,0,0,0.15)] animate-in slide-in-from-right-8 fade-in duration-500 min-w-[320px]"
    >
      <%!-- Icono de Éxito --%>
      <div class="flex-shrink-0 w-10 h-10 bg-green-50 rounded-full flex items-center justify-center text-green-500">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
        </svg>
      </div>

      <%!-- Contenido --%>
      <div class="flex-grow">
        <p class="text-sm font-black text-gray-800 tracking-tight">
          File processing Complete
        </p>
        <p class="text-[10px] font-medium text-gray-400 uppercase tracking-wider">
          Files processed
        </p>
      </div>

      <%!-- Botón de Cierre (Controlado por LiveView) --%>
      <button
        phx-click="close_toast"
        class="text-gray-300 hover:text-gray-500 transition-colors p-1"
      >
        <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
    """
  end
end
