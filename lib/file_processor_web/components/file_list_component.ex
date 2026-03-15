defmodule FileProcessorWeb.FileListComponent do
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  defp filter_rows(js, "all") do
    # Show everything inside the container
    js |> JS.show(to: "#files-stream-container li", display: "block")
  end

  defp filter_rows(js, filter) do
    js
    # FIRST: Hide every single item in the list
    |> JS.hide(to: "#files-stream-container li", transition: "fade-out")
    # SECOND: Show only the ones that match the status
    # We use the data-status attribute we added earlier
    |> JS.show(to: "#files-stream-container li[data-status='#{filter}']", transition: "fade-in", display: "block")
  end
  def file_list(assigns) do
    ~H"""
    <div :if={@processing_started or @all_done} class="bg-white rounded-2xl shadow-sm border overflow-hidden animate-in slide-in-from-bottom-4 duration-700">
      <%!-- HEADER AND FILTERS --%>
      <div class="p-5 border-b bg-gray-50/50 flex flex-col gap-4">
        <div class="flex justify-between items-center">
          <h3 class="font-bold text-gray-800 text-lg tracking-tight italic text-blue-900">Analysis Progress</h3>
          <button :if={@all_done} phx-click="reset_processor" class="px-4 py-1.5 text-xs font-bold rounded-lg bg-indigo-600 text-white hover:bg-indigo-700 transition-all shadow-md">
            New Analysis
          </button>
        </div>

        <div class="flex gap-2">
          <%= for {label, filter_val} <- [{"All", "all"}, {"Completed", "ok"}, {"Warnings", "warning"}, {"Errors", "error"}] do %>
            <button
              type="button"
              phx-click={
                filter_rows(JS.push("set_filter", value: %{filter: filter_val}), filter_val)
              }
              class={"text-[10px] font-black px-4 py-1.5 rounded-full uppercase tracking-widest transition-all duration-300 #{if @filter == filter_val, do: "bg-indigo-600 text-white shadow-lg", else: "bg-gray-100 text-gray-400 hover:bg-gray-200"}"}
            >
              <%= label %>
            </button>
          <% end %>
        </div>
      </div>

      <%!-- FILE LIST --%>
      <ul id="files-stream-container" phx-update="stream" phx-hook="FileListFilter" data-filter={@filter} class="divide-y divide-gray-50 max-h-[400px] overflow-y-auto" phx-update="stream" id="files-stream">
        <%= for {dom_id, file} <- @streams.files_stream do %>
          <li id={dom_id} data-status={Atom.to_string(file.status)} class={["border-b border-gray-50 last:border-0 overflow-hidden transition-all duration-300"]}>
            <div class="p-5 flex justify-between items-center hover:bg-gray-50/50">
              <div class="flex items-center gap-3">
                <div class={"w-2.5 h-2.5 rounded-full #{case file.status do
                  :ok -> "bg-green-500 shadow-[0_0_8px_rgba(34,197,94,0.4)]"
                  :warning -> "bg-yellow-500 shadow-[0_0_8px_rgba(234,179,8,0.4)]"
                  _ -> "bg-red-500 shadow-[0_0_8px_rgba(239,68,68,0.4)]"
                end}"}></div>

                <div class="flex flex-col">
                  <span class="text-sm font-bold text-gray-700 italic"><%= file.name %></span>
                  <span class="text-[10px] text-indigo-500 font-bold uppercase tracking-tight">
                    <%= Map.get(file, :detail, "Analysis pending...") %>
                  </span>
                </div>
              </div>

              <div class="flex items-center gap-3">
                <%!-- Error details button --%>
                <button
                  :if={file.status in [:error, :warning]}
                  phx-click="toggle_error_details"
                  phx-value-name={file.name}
                  class="text-[10px] font-black px-3 py-1 rounded-lg border border-red-200 text-red-500 hover:bg-red-50 transition-all uppercase tracking-widest"
                >
                  <%= if @expanded_error_file == file.name, do: "Close", else: "Details" %>
                </button>
                <span class={"text-[10px] font-black px-2.5 py-1 rounded-md tracking-widest #{if file.status == :ok, do: "bg-green-100 text-green-700", else: "bg-red-100 text-red-700"}"}>
                  <%= String.upcase(Atom.to_string(file.status)) %>
                </span>
              </div>
            </div>

            <%!-- ERRORS INSPECTOR --%>
            <div :if={@expanded_error_file == file.name and @current_error_details} id={"details-#{dom_id}"} class="bg-red-50/50 px-12 py-4 border-t border-red-100">
              <div class="text-[11px] font-mono">
                <%= if is_list(@current_error_details) do %>
                  <p class="text-indigo-700 font-bold mb-1 italic text-xs">Error lines:</p>
                  <ul class="list-disc pl-4 text-red-600 space-y-1">
                    <%= for detail <- @current_error_details do %>
                      <li><%= detail %></li>
                    <% end %>
                  </ul>
                <% else %>
                  <p class="text-red-700 font-bold uppercase tracking-widest text-[9px] mb-1">Processing error:</p>
                  <p class="text-red-600 italic"><%= @current_error_details %></p>
                <% end %>
              </div>
            </div>
          </li>
        <% end %>
      </ul>

      <%!-- SKELETON LOADER --%>
      <div :if={@processing_started and not @all_done} id="skeleton-loader" class="p-5 flex justify-between items-center bg-gray-50/20 animate-pulse">
        <div class="flex items-center gap-3">
          <div class="w-2 h-2 rounded-full bg-indigo-300"></div>
          <div class="h-4 w-48 bg-gray-200 rounded"></div>
        </div>
        <div class="h-5 w-12 bg-gray-100 rounded"></div>
      </div>
    </div>
    """
  end
end
