defmodule FileProcessorWeb.DashboardComponents do
  use Phoenix.Component

  def flash_messages(assigns) do
    ~H"""
    <div class="fixed top-4 left-1/2 -translate-x-1/2 z-[100] w-full max-w-sm">
      <p :if={Phoenix.Flash.get(@flash, :info)}
         class="bg-blue-50 text-blue-800 p-4 rounded-xl shadow-lg border-l-4 border-blue-500 animate-in fade-in zoom-in cursor-pointer"
         phx-click="lv:clear-flash"
         phx-value-key="info">
        <%= Phoenix.Flash.get(@flash, :info) %>
      </p>

      <p :if={Phoenix.Flash.get(@flash, :error)}
         class="bg-red-50 text-red-800 p-4 rounded-xl shadow-lg border-l-4 border-red-500 animate-in fade-in zoom-in cursor-pointer"
         phx-click="lv:clear-flash"
         phx-value-key="error">
        <%= Phoenix.Flash.get(@flash, :error) %>
      </p>
    </div>
    """
  end

  def progress_bar(assigns) do
    mode = Map.get(assigns, :mode, :sequential)
    all_stats = Map.get(assigns, :stats, %{})

    stats = if mode == :sequential do
        Map.get(all_stats, :sequential, %{total: 0, processed: 0, errors: 0, warnings: 0})
      else
        Map.get(all_stats, :parallel, %{total: 0, processed: 0, errors: 0, warnings: 0})
      end

    ~H"""
    <div :if={@processing_started and !@all_done} class="mb-6 animate-in fade-in duration-500">
      <div class="flex justify-between items-end mb-2">
        <div class="flex flex-col">
          <span class="text-[10px] font-bold text-indigo-600 uppercase tracking-widest italic">
            System Analysis in Progress
          </span>
          <span class="text-2xl font-black text-gray-800">
            <%= if stats.total > 0, do: round((stats.processed / stats.total) * 100), else: 0 %>%
          </span>
        </div>
        <span class="text-xs font-bold text-gray-400 italic">
          <%= stats.processed %> / <%= stats.total %> Files Analyzed
        </span>
      </div>

      <div class="h-3 w-full bg-gray-100 rounded-full overflow-hidden shadow-inner border border-gray-50">
        <div
          class="h-full bg-indigo-600 transition-all duration-500 ease-out shadow-[0_0_15px_rgba(79,70,229,0.4)]"
          style={"width: #{if stats.total > 0, do: (stats.processed / stats.total) * 100, else: 0}%"}
        >
          <div class="w-full h-full animate-pulse bg-white/20"></div>
        </div>
      </div>
    </div>
    """
  end
end
