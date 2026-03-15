defmodule FileProcessorWeb.MetricsDashboardComponent do
  use Phoenix.Component
  alias FileProcessorWeb.DonutComponent

  def metrics_dashboard(assigns) do
    mode = Map.get(assigns, :mode, :sequential)
    all_stats = Map.get(assigns, :stats, %{})

    # 1. Safe retrieval of benchmark_stats from assigns
    benchmark_data = Map.get(assigns, :benchmark_stats, %{
      sequential: %{processed: 0, errors: 0, warnings: 0},
      parallel: %{processed: 0, errors: 0, warnings: 0}
    })

    # 2. Extract specific stats for the main cards based on mode
    current_engine_stats = if mode == :benchmark do
      # During benchmark, we use Parallel as the main reference for top cards
      Map.get(benchmark_data, :parallel)
    else
      Map.get(all_stats, mode, %{processed: 0, errors: 0, warnings: 0})
    end

    # 3. CRITICAL FIX: Get the total files count correctly
    # Since @stats stores total inside the mode key (e.g., @stats.sequential.total)
    total_files = get_in(all_stats, [mode, :total]) || 0

    # 4. Consolidate display data
    stats_for_display =
      (current_engine_stats || %{processed: 0, errors: 0, warnings: 0})
      |> Map.put(:total, total_files)

    assigns =
      assigns
      |> assign(:display_stats, stats_for_display)
      |> assign(:benchmark_data, benchmark_data)

    ~H"""
    <div
      :if={@processing_started or @all_done}
      id="metrics-dashboard-container"
      class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8 animate-in zoom-in-95 duration-500"
    >
      <%!-- Card: Total Files --%>
      <div class="bg-white p-6 rounded-2xl shadow-sm border-t-4 border-t-indigo-500">
        <p class="text-xs font-bold text-gray-400 uppercase tracking-wider italic text-blue-900">Total Files</p>
        <p id="total-count" phx-hook="CountUp" data-target={@display_stats.total} class="text-3xl font-black text-gray-800 mt-1">
          <%= @display_stats.total %>
        </p>
      </div>

      <%!-- Card: Processed Files --%>
      <div class="bg-white p-6 rounded-2xl shadow-sm border-t-4 border-t-green-500">
        <p class="text-xs font-bold text-gray-400 uppercase tracking-wider italic text-blue-900">Processed</p>
        <p id="processed-count" phx-hook="CountUp" data-target={@display_stats.processed} class="text-3xl font-black text-gray-800 mt-1">
          <%= @display_stats.processed %>
        </p>
      </div>

      <%!-- Card: Errors --%>
      <div
        phx-click="set_filter"
        phx-value-filter="error"
        class="bg-white p-6 rounded-2xl shadow-sm border-t-4 border-t-red-500 cursor-pointer hover:bg-red-50 transition-colors group"
      >
        <p class="text-xs font-bold text-gray-400 uppercase tracking-wider italic text-blue-900">Errors</p>
        <div class="flex items-center justify-between">
          <p id="errors-count" phx-hook="CountUp" data-target={@display_stats.errors} class="text-3xl font-black text-red-600 mt-1">
            <%= @display_stats.errors %>
          </p>
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-red-300 group-hover:text-red-500" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M3 3a1 1 0 011-1h12a1 1 0 011 1v3a1 1 0 01-.293.707L12 11.414V15a1 1 0 01-.293.707l-2 2A1 1 0 018 17v-5.586L3.293 6.707A1 1 0 013 6V3z" clip-rule="evenodd" />
          </svg>
        </div>
      </div>

      <%!-- Benchmark Race Track Section --%>
      <div :if={@mode == :benchmark} class="col-span-full mt-4 p-6 bg-gray-900 rounded-2xl border border-gray-800 shadow-xl">
        <div class="flex items-center gap-2 mb-4">
          <div class="w-2 h-2 rounded-full bg-indigo-500 animate-pulse"></div>
          <h3 class="text-[10px] font-black text-indigo-400 uppercase tracking-widest italic">Live Engine Race</h3>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
          <%!-- Sequential Track --%>
          <div class="space-y-2">
            <div class="flex justify-between text-[9px] font-bold text-gray-500 uppercase">
              <span>Sequential</span>
              <%!-- FIXED: Accessing total via @display_stats instead of @stats.total --%>
              <span><%= @benchmark_data.sequential.processed %> / <%= @display_stats.total %></span>
            </div>
            <div class="h-2 w-full bg-gray-800 rounded-full overflow-hidden">
              <div class="h-full bg-amber-500 transition-all duration-500"
                style={"width: #{(@benchmark_data.sequential.processed / max(@display_stats.total, 1)) * 100}%"}></div>
            </div>
          </div>

          <%!-- Parallel Track --%>
          <div class="space-y-2">
            <div class="flex justify-between text-[9px] font-bold text-indigo-400 uppercase">
              <span>Parallel (Multi-core)</span>
              <span><%= @benchmark_data.parallel.processed %> / <%= @display_stats.total %></span>
            </div>
            <div class="h-2 w-full bg-gray-800 rounded-full overflow-hidden">
              <div class="h-full bg-indigo-500 shadow-[0_0_10px_rgba(99,102,241,0.6)] transition-all duration-500"
                style={"width: #{(@benchmark_data.parallel.processed / max(@display_stats.total, 1)) * 100}%"}></div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Donut component --%>
      <.live_component
        module={DonutComponent}
        id="success-donut"
        percentage={if @display_stats.total > 0, do: ((@display_stats.processed - @display_stats.errors) / @display_stats.total) * 100, else: 0}
      />
    </div>
    """
  end
end
