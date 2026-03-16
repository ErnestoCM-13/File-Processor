defmodule FileProcessorWeb.DetailedReportComponent do
  use FileProcessorWeb, :live_component
  alias Phoenix.LiveView.JS
  alias FileProcessor.ResultsCache

  def update(assigns, socket) do
    results = if assigns[:results_id], do: ResultsCache.get_processment_results(assigns.results_id), else: nil

    {:ok,
      socket
      |> assign(assigns)
      |> assign(:results, results)
      |> assign_filtered_items(results, assigns[:current_file_details_filter], assigns[:selected_file])}
  end

  def render(assigns) do
    ~H"""
    <div id="detailed-report-section" class="mt-12 space-y-6 bg-white rounded-2xl">
      <%!-- HEADER --%>
      <div class="flex items-center justify-between border-b border-gray-100 pb-4 p-4">
        <h2 class="font-bold text-gray-800 text-lg tracking-tight italic text-blue-900">
          Analysis Details
        </h2>

        <%!-- FILTERS --%>
        <div :if={@results} class="flex items-center gap-2">
          <%= for file <- ["all", "csv", "json", "log"] do %>
            <button
              phx-click="set_report_filter"
              phx-value-filter={file}
              class={["px-3 py-1 text-[10px] font-bold rounded-full transition-all uppercase tracking-widest",
              if(@current_file_details_filter == file, do: "bg-indigo-600 text-white", else: "bg-gray-100 text-gray-500 hover:bg-gray-200")]}
            >
              <%= file %>
            </button>
          <% end %>

          <%!-- SELECTED FILE FILTER --%>
          <div :if={@selected_file} class="flex items-center gap-2 px-3 py-1 bg-amber-100 text-amber-700 rounded-full animate-in zoom-in">
            <span class="text-[10px] font-bold uppercase tracking-widest">File: <%= @selected_file %></span>
            <button phx-click="clear_file_filter">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
              </svg>
            </button>
          </div>
        </div>
      </div>

      <%!-- CONTENT --%>
      <div class="space-y-4">
        <%= if @results do %>
          <%= if Enum.empty?(@filtered_items) do %>
            <div class="p-12 text-center bg-gray-50 rounded-2xl border border-dashed border-gray-200 text-gray-400">
              No files match the selected filter.
            </div>
          <% else %>
            <%= for entry <- @filtered_items do %>
              <.report_row
                entry={entry}
                expanded?={@expanded_error_file == entry.file}
                error_details={@current_error_details}
              />
            <% end %>
          <% end %>
        <% else %>
          <%!-- SKELETON --%>
          <div :for={_ <- 1..3} class="bg-white p-6 rounded-2xl border border-gray-100 animate-pulse space-y-4">
            <div class="h-4 bg-gray-100 rounded w-1/4"></div>
            <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
              <div :for={_ <- 1..4} class="h-8 bg-gray-50 rounded"></div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp report_row(assigns) do
    ~H"""
    <div class={["bg-white rounded-2xl shadow-sm border transition-all overflow-hidden",
      if(@entry[:is_critical], do: "border-red-100 bg-red-50/10", else: "border-gray-100"),
      if(@expanded?, do: "border-red-200 ring-1 ring-red-100", else: "border-gray-100")]}
    >
      <div class="p-6">
        <div class="flex items-center justify-between mb-4 border-b border-gray-50 pb-2">
          <div class="flex items-center gap-2">
            <span class={["text-xs font-black uppercase tracking-widest",
              if(@entry[:is_critical], do: "text-red-600", else: "text-indigo-600")]}>
              <%= @entry.file %>
            </span>
            <%!-- ERROR DETAILS BUTTON --%>
            <%
              has_errors? =
                @entry[:is_critical] ||
                (Map.get(@entry, :internal_errors, []) != []) ||
                (get_in(@entry, [:metrics, :errors_found]) || 0) > 0
            %>
            <button
              :if={has_errors?}
              phx-click="toggle_error_details"
              phx-value-name={@entry.file}
              class={[
                "text-[9px] px-2 py-0.5 rounded font-bold uppercase transition-colors",
                if(@expanded?,
                  do: "bg-red-600 text-white",
                  else: "bg-red-100 text-red-700 hover:bg-red-200")
              ]}
            >
              <%= if @expanded?, do: "Hide Details", else: "View Reason" %>
            </button>
          </div>
          <span class="px-2 py-0.5 bg-gray-100 text-[8px] font-bold text-gray-500 rounded uppercase"><%= @entry.type %></span>
        </div>

        <%!-- MOSTRAR MÉTRICAS O MENSAJE DE ERROR --%>
        <%= if @entry[:is_critical] do %>
          <div class="flex items-center gap-3 text-red-500 italic py-2">
            <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
            <span class="text-sm font-medium">Critical Failure: Processing aborted for this file.</span>
          </div>
        <% else %>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <%= for {key, value} <- @entry.metrics do %>
              <div :if={key != :error_details} class="flex flex-col">
                <span class="text-[9px] font-black text-gray-400 uppercase mb-1"><%= String.replace(to_string(key), "_", " ") %></span>
                <span class="text-sm font-bold text-gray-700"><%= format_value(value) %></span>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <%!-- ERRORS INSPECTOR --%>
      <div :if={@expanded? and @error_details} class="bg-red-50 border-t border-red-100 p-6 animate-in slide-in-from-top-2">
        <h4 class="text-[10px] font-black text-red-700 uppercase tracking-widest mb-3">Error Details</h4>
        <div class="bg-white/50 rounded-xl p-4 text-xs font-mono text-red-600 border border-red-100 shadow-inner">
          <%= if is_list(@error_details) do %>
            <ul class="list-disc pl-4 space-y-1">
              <%= for detail <- @error_details do %>
                <li><%= detail %></li>
              <% end %>
            </ul>
          <% else %>
            <p><%= @error_details %></p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # --- HELPERS ---

  defp assign_filtered_items(socket, nil, _, _), do: assign(socket, :filtered_items, [])

  defp assign_filtered_items(socket, results, filter, selected_file) do
    successful_items =
      [:csv, :json, :log]
      |> Enum.flat_map(fn type ->
        Map.get(results, type, [])
        |> Enum.map(&Map.put(&1, :type, type))
      end)

    error_items =
      Map.get(results, :errors, [])
      |> Enum.map(fn e ->
        %{
          file: e.file,
          type: :error,
          metrics: %{},
          internal_errors: [e.reason],
          is_critical: true
        }
      end)

    filtered =
      (successful_items ++ error_items)
      |> Enum.filter(fn item ->
        type_match = (filter == "all" || to_string(item.type) == filter)
        file_match = (selected_file == nil || item.file == selected_file)
        type_match && file_match
      end)

    assign(socket, :filtered_items, filtered)
  end

  # --- FORMAT HELPERS ---

  defp format_value(val) when is_list(val), do: if(Enum.empty?(val), do: "None", else: "#{Enum.count(val)} items")
  defp format_value(val) when is_float(val), do: Float.round(val, 2)
  defp format_value(val) when is_nil(val) or val == "", do: "N/A"
  defp format_value(val), do: val
end
