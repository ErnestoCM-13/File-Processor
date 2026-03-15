defmodule FileProcessorWeb.MetricsDashboardComponent do
  use Phoenix.Component

  alias FileProcessorWeb.DonutComponent

  def metrics_dashboard(assigns) do
    target_mode = if assigns.mode == :sequential, do: :sequential, else: :parallel

    display_stats = Map.get(assigns.stats, target_mode, %{total: 0, processed: 0, errors: 0, warnings: 0})

    percentage = calculate_percentage(display_stats)

    assigns =
      assigns
      |> assign(:display_stats, display_stats)
      |> assign(:percentage, percentage)

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

      <%!-- Donut component --%>
      <.live_component
        module={DonutComponent}
        id="main-process-donut"
        percentage={@percentage}
      />

      <%!-- Benchmark Race Track Section --%>
      <div :if={@mode == :benchmark} class="col-span-full mt-4 p-6 bg-gray-900 rounded-2xl border border-gray-800 shadow-xl">
        <div class="flex items-center gap-2 mb-4">
          <div class="w-2 h-2 rounded-full bg-indigo-500 animate-pulse"></div>
          <h3 class="text-[10px] font-black text-indigo-400 uppercase tracking-widest italic">Live Engine Race</h3>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
          <%!-- Parallel Track --%>
          <div class="space-y-2">
            <div class="flex justify-between text-[9px] font-bold text-indigo-400 uppercase">
              <span>Parallel</span>
              <span><%= @stats.parallel.processed %> / <%= @display_stats.total %></span>
            </div>
            <div class="h-2 w-full bg-gray-800 rounded-full overflow-hidden">
              <div class="h-full bg-indigo-500 shadow-[0_0_10px_rgba(99,102,241,0.6)] transition-all duration-500"
                style={"width: #{render_progress(@stats.parallel.processed, @display_stats.total)}%"}></div>
            </div>
          </div>

          <%!-- Sequential Track --%>
          <div class="space-y-2">
            <div class="flex justify-between text-[9px] font-bold text-gray-500 uppercase">
              <span>Sequential</span>
              <span><%= @stats.sequential.processed %> / <%= @display_stats.total %></span>
            </div>
            <div class="h-2 w-full bg-gray-800 rounded-full overflow-hidden">
              <div class="h-full bg-amber-500 transition-all duration-500"
                style={"width: #{render_progress(@stats.sequential.processed, @display_stats.total)}%"}></div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ------------------------
  # HELPERS
  # ------------------------

  defp calculate_percentage(%{total: 0}), do: 0
  defp calculate_percentage(%{total: total, processed: processed, errors: errors}) do
    success_count = max(processed - errors, 0)
    (success_count / total) * 100
  end

  defp render_progress(current, total) do
    cond do
      total <= 0 -> 0
      current >= total -> 100
      true -> (current / total) * 100
    end
  end
end
