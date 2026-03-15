defmodule FileProcessorWeb.MetricsDashboardComponent do
  use Phoenix.Component

  alias FileProcessorWeb.DonutComponent

  def metrics_dashboard(assigns) do
    mode = Map.get(assigns, :mode, :sequential)
    all_stats = Map.get(assigns, :stats, %{})

    stats = if mode == :sequential do
        Map.get(all_stats, :sequential, %{total: 0, processed: 0, errors: 0, warnings: 0})
      else
        Map.get(all_stats, :parallel, %{total: 0, processed: 0, errors: 0, warnings: 0})
      end


    ~H"""
    <div
      :if={@processing_started or @all_done}
      id="metrics-dashboard-container"
      class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8 animate-in zoom-in-95 duration-500"
    >
      <%!-- Card: Total Files --%>
      <div class="bg-white p-6 rounded-2xl shadow-sm border-t-4 border-t-indigo-500">
        <p class="text-xs font-bold text-gray-400 uppercase tracking-wider italic">Total Files</p>
        <p id="total-count" phx-hook="CountUp" data-target={stats.total} class="text-3xl font-black text-gray-800 mt-1">
          <%= stats.total %>
        </p>
      </div>

      <%!-- Card: Processed Files --%>
      <div class="bg-white p-6 rounded-2xl shadow-sm border-t-4 border-t-green-500">
        <p class="text-xs font-bold text-gray-400 uppercase tracking-wider italic">Processed</p>
        <p id="processed-count" phx-hook="CountUp" data-target={stats.processed} class="text-3xl font-black text-gray-800 mt-1">
          <%= stats.processed %>
        </p>
      </div>

      <%!-- Card: Errors --%>
      <div
        phx-click="set_filter"
        phx-value-filter="error"
        class="bg-white p-6 rounded-2xl shadow-sm border-t-4 border-t-red-500 cursor-pointer hover:bg-red-50 transition-colors group"
      >
        <p class="text-xs font-bold text-gray-400 uppercase tracking-wider italic">Errors</p>
        <div class="flex items-center justify-between">
          <p id="errors-count" phx-hook="CountUp" data-target={stats.errors} class="text-3xl font-black text-red-600 mt-1">
            <%= stats.errors %>
          </p>
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-red-300 group-hover:text-red-500" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M3 3a1 1 0 011-1h12a1 1 0 011 1v3a1 1 0 01-.293.707L12 11.414V15a1 1 0 01-.293.707l-2 2A1 1 0 018 17v-5.586L3.293 6.707A1 1 0 013 6V3z" clip-rule="evenodd" />
          </svg>
        </div>
      </div>

      <%!-- Donut component --%>
      <.live_component
        module={FileProcessorWeb.DonutComponent}
        id="success-donut"
        percentage={if stats.total > 0, do: ((stats.processed - stats.errors) / stats.total) * 100, else: 0}
      />
    </div>
    """
  end
end
