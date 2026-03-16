defmodule FileProcessorWeb.FileListComponent do
  use Phoenix.Component


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
              phx-click="set_filter"
              phx-value-filter={filter_val}
              class={"text-[10px] font-black px-4 py-1.5 rounded-full uppercase tracking-widest transition-all duration-300 #{if @file_list_filter == filter_val, do: "bg-indigo-600 text-white shadow-lg", else: "bg-gray-100 text-gray-400 hover:bg-gray-200"}"}
            >
              <%= label %>
            </button>
          <% end %>
        </div>
      </div>

      <%!-- FILE LIST --%>
      <ul id="files-stream-container" phx-update="stream"  data-filter={@file_list_filter} class="divide-y divide-gray-50 max-h-[400px] overflow-y-auto">
        <%= for {dom_id, file} <- @streams.files_stream do %>
          <li id={dom_id}
            data-status={to_string(file.status)}
            class="file-item border-b border-gray-50 last:border-0 overflow-hidden transition-all duration-300"
          >
            <div
              class="cursor-pointer hover:bg-indigo-50"
              phx-click="select_file_for_report"
              phx-value-name={file.name}
            >
              <div class="p-5 flex justify-between items-center hover:bg-gray-50/50">
                <div class="flex items-center gap-3">
                  <div class={"w-2.5 h-2.5 rounded-full #{case file.status do
                    :ok -> "bg-green-500 shadow-[0_0_8px_rgba(34,197,94,0.4)]"
                    :warning -> "bg-yellow-500 shadow-[0_0_8px_rgba(234,179,8,0.4)]"
                    _ -> "bg-red-500 shadow-[0_0_8px_rgba(239,68,68,0.4)]"
                  end}"}>
                  </div>

                  <div class="flex flex-col">
                    <span class="text-sm font-bold text-gray-700 italic"><%= file.name %></span>
                    <span class="text-[10px] text-indigo-500 font-bold uppercase tracking-tight">
                      <%= Map.get(file, :detail, "Analysis pending...") %>
                    </span>
                  </div>
                </div>

                <div class="flex items-center gap-3">
                  <span class={"text-[10px] font-black px-2.5 py-1 rounded-md tracking-widest #{if file.status == :ok, do: "bg-green-100 text-green-700", else: "bg-red-100 text-red-700"}"}>
                    <%= String.upcase(Atom.to_string(file.status)) %>
                  </span>
                </div>
              </div>
            </div>
          </li>
          <%!-- SKELETON LOADER --%>
          <li :if={@processing_started and not @all_done} id="skeleton-loader" class="p-5 flex justify-between items-center bg-gray-50/20 animate-pulse">
            <div class="flex items-center gap-3">
              <div class="w-2 h-2 rounded-full bg-indigo-300"></div>
              <div class="h-4 w-48 bg-gray-200 rounded"></div>
            </div>
            <div class="h-5 w-12 bg-gray-100 rounded"></div>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end
end
