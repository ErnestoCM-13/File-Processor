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
            <.race_track label="Parallel" current={@stats.parallel.processed + @stats.parallel.warnings + @stats.parallel.errors} total={@display_stats.total} color="bg-indigo-500" />
            <.race_track label="Sequential" current={@stats.sequential.processed + @stats.sequential.warnings + @stats.sequential.errors} total={@display_stats.total} color="bg-amber-500" />
          </div>

          <%!-- Performance Panel --%>
          <div class="bg-gray-100 rounded-xl p-4 border border-gray-300 flex flex-col justify-center min-h-[140px]">
            <%= if @all_done and @performance do %>
              <div class="space-y-3 animate-in fade-in slide-in-from-right-4 duration-700">
                <div class="flex justify-between text-[11px] border-b border-gray-300 pb-1">
                  <span class="font-bold text-gray-700 uppercase">Parallel Time</span>
                  <span class="font-bold text-gray-700"><%= Float.round(@performance.parallel_time, 4) %>s</span>
                </div>
                <div class="flex justify-between text-[11px] border-b border-gray-300 pb-1">
                  <span class="font-bold text-gray-700 uppercase">Sequential Time</span>
                  <span class="font-bold text-gray-700"><%= Float.round(@performance.sequential_time, 4) %>s</span>
                </div>
                <div class="flex justify-between text-[11px] border-b border-gray-300 pb-1">
                  <span class="font-bold text-gray-700 uppercase">Max Memory</span>
                  <span class="font-bold text-gray-700"><%= @performance.memory_max %>MB</span>
                </div>
                <div class="mt-2 bg-indigo-600 rounded p-2 text-center shadow-lg shadow-indigo-900/20">
                  <p class="text-[10px] font-bold text-indigo-100 uppercase">Improvement</p>
                  <p class="text-xl font-black text-white"><%= @performance.improvement %>x</p>
                </div>
              </div>
            <% else %>
              <div class="animate-pulse space-y-3">
                <div class="h-2 bg-gray-700 rounded w-3/4"></div>
                <div class="h-2 bg-gray-700 rounded w-full"></div>
                <div class="h-10 bg-gray-700 rounded w-full mt-2"></div>
                <p class="text-[8px] text-gray-500 text-center uppercase tracking-tighter">Calculating performance...</p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def update(assigns, socket) do
    target_mode = if assigns.mode == :sequential, do: :sequential, else: :parallel
    display_stats = Map.get(assigns.stats, target_mode, %{total: 0, processed: 0, errors: 0, warnings: 0})

    performance = get_performance(assigns[:results_id])

    if assigns[:all_done] && is_nil(performance) && assigns[:results_id] do
      Process.send_after(self(), {:retry_performance, assigns.id}, 100)
    end

    {:ok, socket
      |> assign(assigns)
      |> assign(
        display_stats: display_stats,
        percentage: calculate_percentage(display_stats),
        performance: performance
      )}
  end

  # ------------------------
  # HELPERS
  # ------------------------

  defp metric_card(assigns) do
    color_classes = %{
      "indigo" => %{border: "border-t-indigo-500", text: "text-indigo-600"},
      "green"  => %{border: "border-t-green-500", text: "text-green-600"},
      "yellow" => %{border: "border-t-yellow-500", text: "text-yellow-600"},
      "red"    => %{border: "border-t-red-500", text: "text-red-600"}
    }

    classes = Map.get(color_classes, assigns.color, %{border: "border-t-gray-500", text: "text-gray-800"})

    assigns = assign(assigns, :classes, classes)

    ~H"""
    <div class={"bg-white p-6 rounded-2xl shadow-sm border-t-4 border-t-#{@color}-500"}>
      <p class="text-xs font-bold text-gray-400 uppercase tracking-wider italic text-blue-900"><%= @title %></p>
      <p phx-hook="CountUp" id={"#{@title}-count"} data-target={@value} class={"text-3xl font-black text-#{@color}-600 mt-1"}>
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

  defp get_performance(nil), do: nil
  defp get_performance(id) do
    case ResultsCache.get_processment_results(id) do
      %{performance: perf} when is_map(perf) -> perf
      _ -> nil
    end
  end

  defp calculate_percentage(%{total: 0}), do: 0
  defp calculate_percentage(%{total: total, warnings: _warnings, errors: errors}) do
    processed = max(total - errors, 0)
    processed * 100 / total
  end

  defp render_progress(0, _), do: 0
  defp render_progress(c, t) when c >= t, do: 100
  defp render_progress(c, t), do: (c / t) * 100
end
