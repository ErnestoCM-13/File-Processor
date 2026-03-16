defmodule FileProcessorWeb.DonutComponent do
  use FileProcessorWeb, :live_component

  def update(assigns, socket) do
    stats = assigns.display_stats || %{processed: 0, ok: 0, warnings: 0, errors: 0}

    segments = calculate_segments(stats)

    {:ok, socket |> assign(assigns) |> assign(:segments, segments)}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center p-4 bg-white rounded-2xl shadow-sm border">
      <h4 class="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-4">Live Success Rate</h4>
      <div class="relative w-32 h-32">
        <svg viewBox="0 0 36 36" class="w-full h-full transform -rotate-90">
          <%!-- Gray circle (initial state) --%>
          <circle
            cx="18" cy="18" r="15.9155"
            fill="transparent"
            stroke="#f3f4f6"
            stroke-width="4"
          />

          <%!-- Green segment (:ok) --%>
          <circle
            cx="18" cy="18" r="15.9155"
            fill="transparent"
            stroke="#10b981"
            stroke-width="4"
            stroke-dasharray={@segments.ok.array}
            stroke-dashoffset="0"
            class="transition-all duration-500 ease-in-out"
          />

          <%!-- Yellow segment (:warning) --%>
          <circle
            cx="18" cy="18" r="15.9155"
            fill="transparent"
            stroke="#f59e0b"
            stroke-width="4"
            stroke-dasharray={@segments.warning.array}
            stroke-dashoffset={@segments.warning.offset}
            class="transition-all duration-500 ease-in-out"
          />

          <%!-- Red segment (:error) --%>
          <circle
            cx="18" cy="18" r="15.9155"
            fill="transparent"
            stroke="#ef4444"
            stroke-width="4"
            stroke-dasharray={@segments.error.array}
            stroke-dashoffset={@segments.error.offset}
            class="transition-all duration-500 ease-in-out"
          />
        </svg>

        <%!-- Success percentage --%>
        <div class="absolute inset-0 flex flex-col items-center justify-center">
          <span class="text-2xl font-black text-gray-800"><%= round(@percentage) %>%</span>
          <span class="text-[8px] font-bold text-gray-400 uppercase">Success</span>
        </div>
      </div>
    </div>
    """
  end

  # ------------------------
  # SEGMENTS LOGIC
  # ------------------------

  defp calculate_segments(%{processed: 0}) do
    # Initial state
    empty = %{array: "0 100", offset: "0"}
    %{ok: empty, warning: empty, error: empty}
  end

  defp calculate_segments(stats) do
    total = stats.processed

    ok_percentage = (stats.processed - stats.warnings - stats.errors) / total * 100
    warn_percentage = stats.warnings / total * 100
    err_percentage = stats.errors / total * 100

    %{
      ok: %{
        array: "#{ok_percentage} #{100 - ok_percentage}",
        offset: "0"
      },
      warning: %{
        array: "#{warn_percentage} #{100 - warn_percentage}",
        offset: "-#{ok_percentage}"
      },
      error: %{
        array: "#{err_percentage} #{100 - err_percentage}",
        offset: "-#{ok_percentage + warn_percentage}"
      }
    }
  end
end
