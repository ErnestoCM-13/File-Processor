defmodule FileProcessorWeb.ExecutiveSummaryComponent do
  @moduledoc """
  Renders the final detailed report, categorizing metrics by file type.
  It dynamically extracts all calculated values from the strategy structs.
  """
  use Phoenix.Component

  def executive_summary(assigns) do
    ~H"""
    <div class="mt-12 space-y-8 animate-in slide-in-from-bottom-8 duration-1000">
      <div class="flex items-center gap-4 mb-6">
        <div class="h-[2px] flex-grow bg-gray-200"></div>
        <h2 class="text-xs font-black text-gray-400 uppercase tracking-[0.3em] italic">
          Detailed Analysis Report
        </h2>
        <div class="h-[2px] flex-grow bg-gray-200"></div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 items-start">
        <%!-- Render only if there are items in the specific list --%>
        <.summary_card
          :if={not Enum.empty?(@final_metrics.csv)}
          title="CSV Analysis"
          color="border-emerald-500"
          items={@final_metrics.csv}
        />

        <.summary_card
          :if={not Enum.empty?(@final_metrics.json)}
          title="JSON Analysis"
          color="border-indigo-500"
          items={@final_metrics.json}
        />

        <.summary_card
          :if={not Enum.empty?(@final_metrics.log)}
          title="Log Analysis"
          color="border-slate-800"
          items={@final_metrics.log}
        />
      </div>
    </div>
    """
  end

  defp summary_card(assigns) do
    ~H"""
    <div class={"bg-white rounded-2xl p-6 shadow-sm border-t-4 #{@color}"}>
      <h3 class="font-black text-gray-900 italic mb-4 uppercase text-sm tracking-tight">
        <%= @title %>
      </h3>

      <div class="space-y-6">
        <%= for entry <- @items do %>
          <div class="p-4 bg-gray-50 rounded-xl border border-gray-100">
            <p class="text-[10px] font-black text-indigo-600 mb-3 truncate uppercase tracking-wider border-b border-gray-200 pb-1">
              FILE: <%= entry.file %>
            </p>

            <div class="grid grid-cols-1 gap-y-3">
              <%!-- Iterate through all available metrics returned by the strategy --%>
              <%= for {key, value} <- safe_metrics(entry.metrics) do %>
                <div class="flex flex-col border-l-2 border-gray-200 pl-2">
                  <span class="text-[8px] text-gray-400 uppercase font-black tracking-tighter leading-tight">
                    <%= String.replace(to_string(key), "_", " ") %>
                  </span>
                  <span class="text-xs font-bold text-gray-800 break-words">
                    <%= format_value(value) %>
                  </span>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Cleans the metrics struct and prepares it for the UI.
  It converts structs to maps and removes only strictly internal metadata.
  """
  defp safe_metrics(metrics) do
    # Convert internal strategy structs (CSV/JSON/LOG) to maps
    metrics_map = if is_struct(metrics), do: Map.from_struct(metrics), else: metrics

    # We only remove internal Elixir/Phoenix metadata keys.
    # We KEEP everything else (including error counts and details).
    Map.drop(metrics_map, [:__struct__, :__meta__])
  end

  @doc """
  Formats complex values (Lists, Floats, Strings) for clean UI display.
  """
  defp format_value(val) when is_list(val) do
    if Enum.empty?(val) do
      "None"
    else
      # Joins list items with a bullet point if they are strings (like error details)
      val
      |> Enum.take(5) # Limits to first 5 items to keep UI clean
      |> Enum.join(", ")
    end
  end

  defp format_value(val) when is_float(val), do: Float.round(val, 2)
  defp format_value(val) when is_nil(val) or val == "", do: "N/A"
  defp format_value(val) when is_map(val), do: "#{Enum.count(val)} entries"
  defp format_value(val), do: val
end
