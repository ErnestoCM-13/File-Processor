defmodule FileProcessorWeb.DonutComponent do
  use FileProcessorWeb, :live_component

  @doc """
  Renders a dynamic SVG donut chart.
  Documentation: The 'stroke-dasharray' calculation allows the circle
  to close in real-time based on the Success Rate.
  """
  def render(assigns) do
    # Stroke calculations for a radius of 15.9155
    # Circumference = 2 * pi * r ≈ 100
    percentage = assigns.percentage || 0
    stroke_value = "#{percentage} #{100 - percentage}"

    ~H"""
    <div class="flex flex-col items-center justify-center p-4 bg-white rounded-2xl shadow-sm border">
      <h4 class="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-4">Live Success Rate</h4>
      <div class="relative w-32 h-32">
        <svg viewBox="0 0 36 36" class="w-full h-full transform -rotate-90">
          <%!-- Background Circle --%>
          <circle
            cx="18" cy="18" r="15.9155"
            fill="transparent"
            stroke="#f3f4f6"
            stroke-width="3"
          />
          <%!-- Dynamic Success Circle --%>
          <circle
            cx="18" cy="18" r="15.9155"
            fill="transparent"
            stroke="#4f46e5"
            stroke-width="3"
            stroke-dasharray={stroke_value}
            stroke-dashoffset="0"
            class="transition-all duration-1000 ease-out"
          />
        </svg>
        <%!-- Center Text --%>
        <div class="absolute inset-0 flex items-center justify-center">
          <span class="text-2xl font-black text-gray-800"><%= round(percentage) %>%</span>
        </div>
      </div>
    </div>
    """
  end
end
