defmodule FileProcessorWeb.MetricsDashboardComponent do
  use FileProcessorWeb, :live_component
  alias FileProcessor.ResultsCache

  def render(assigns) do
    ~H"""
    <div id={@id} class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8 animate-in zoom-in-95 duration-500">
      <div class="md:col-span-4 grid grid-cols-3 grid-rows-2 gap-4">
        <%!-- Card: Total Files --%>
        <div class="col-start-1 row-start-1">
            <.metric_card title="Total Files" value={@display_stats.total} color="indigo" />
          </div>

        <%!-- Card: Processed --%>
        <div class="col-start-2 row-start-1">
            <.metric_card title="Processed" value={@display_stats.processed} color="green" />
          </div>

        <%!-- Card: Warning --%>
        <div class="col-start-1 row-start-2">
            <.metric_card title="Warning" value={@display_stats.warnings} color="yellow" />
          </div>

        <%!-- Card: Errors --%>
        <div class="col-start-2 row-start-2">
            <.metric_card title="Error" value={@display_stats.errors} color="red" />
          </div>

        <%!-- Donut component --%>
        <div class="col-start-3 row-start-1 row-span-2 flex items-center justify-center">
        <.live_component
          module={FileProcessorWeb.DonutComponent}
          id="main-process-donut"
          percentage={@percentage}
          display_stats={@display_stats}
        />
        </div>
      </div>

      <%!-- Benchmark Section --%>
      <div :if={@mode == :benchmark} class="col-span-full mt-4 p-6 bg-white rounded-2xl border border-gray-800 shadow-xl overflow-hidden">
        <div class="flex justify-between items-center mb-6">
          <div class="flex items-center gap-2">
            <h3 class="font-bold text-gray-800 text-lg tracking-tight italic text-blue-90">Live Engine Race</h3>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <%!-- Tracks --%>
          <div class="lg:col-span-2 space-y-6">
            <.race_track label="Parallel" current={@stats.parallel.processed} total={@display_stats.total} color="bg-indigo-500" />
            <.race_track label="Sequential" current={@stats.sequential.processed} total={@display_stats.total} color="bg-amber-500" />
          </div>

        </div>
      </div>
    </div>
    """
  end

  def update(assigns, socket) do
    target_mode = if assigns.mode == :sequential, do: :sequential, else: :parallel
    display_stats = Map.get(assigns.stats, target_mode, %{total: 0, processed: 0, errors: 0, warnings: 0})

    {:ok, socket
      |> assign(assigns)
      |> assign(
        display_stats: display_stats,
        percentage: calculate_percentage(display_stats)
      )}
  end

  # ------------------------
  # HELPERS
  # ------------------------

  defp metric_card(assigns) do
    ~H"""
    <div class={"bg-white p-6 rounded-2xl shadow-sm border-t-4 border-t-#{@color}-500"}>
      <p class="text-xs font-bold text-gray-400 uppercase tracking-wider italic text-blue-900"><%= @title %></p>
      <p phx-hook="CountUp" id={"#{@title}-count"} data-target={@value} class="text-3xl font-black text-gray-800 mt-1">
        <%= @value %>
      </p>
    </div>
    """
  end

  defp race_track(assigns) do
    ~H"""
    <div class="space-y-2">
      <div class="flex justify-between text-[9px] font-bold text-gray-400 uppercase">
        <span><%= @label %></span>
        <span><%= @current %> / <%= @total %></span>
      </div>
      <div class="h-2 w-full bg-gray-800 rounded-full overflow-hidden border border-gray-700">
        <div class={["h-full transition-all duration-500", @color]}
          style={"width: #{render_progress(@current, @total)}%"}></div>
      </div>
    </div>
    """
  end

  defp calculate_percentage(%{total: 0}), do: 0
  defp calculate_percentage(%{total: t, processed: p, errors: e}), do: (max(p - e, 0) / t) * 100

  defp render_progress(0, _), do: 0
  defp render_progress(c, t) when c >= t, do: 100
  defp render_progress(c, t), do: (c / t) * 100
end
