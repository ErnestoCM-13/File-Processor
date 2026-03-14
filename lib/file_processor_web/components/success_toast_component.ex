defmodule FileProcessorWeb.SuccessToastComponent do
  use Phoenix.Component

  def success_toast(assigns) do
    ~H"""
    <div
      :if={@all_done}
      id="success-toast"
      class="fixed top-8 right-8 z-50 flex flex-col gap-2 p-5 bg-white border-l-4 border-green-500 rounded-2xl shadow-[0_20px_50px_rgba(0,0,0,0.1)] animate-in slide-in-from-right-8 fade-in duration-500 w-80"
    >
      <p class="text-sm font-black text-gray-800 tracking-tight italic">
        Batch Analysis Complete
      </p>

      <div class="mt-2 py-3 border-t border-gray-50 grid grid-cols-2 gap-2 text-center">
        <div class="flex flex-col">
          <span class="text-[9px] font-bold text-gray-400 uppercase">Total Items</span>
          <span id="toast-total-rows" phx-hook="CountUp" data-target={@total_rows} class="text-lg font-black text-indigo-600">
            <%= @total_rows %>
          </span>
        </div>

        <div class="flex flex-col">
          <span class="text-[9px] font-bold text-gray-400 uppercase">Files</span>
          <span id="toast-files-count" phx-hook="CountUp" data-target={@stats.processed} class="text-lg font-black text-gray-700">
            <%= @stats.processed %>
          </span>
        </div>
      </div>

      <%!-- CLOSE BUTTON --%>
      <button onclick="this.parentElement.remove()" class="absolute top-2 right-2 text-gray-300 hover:text-gray-500">
        <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
      </button>
    </div>
    """
  end
end
