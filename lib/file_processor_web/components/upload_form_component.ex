defmodule FileProcessorWeb.UploadFormComponent do
  use Phoenix.Component

  def upload_form(assigns) do
    ~H"""
    <%= unless @processing_started or @all_done do %>
    <div class="bg-white p-8 rounded-2xl shadow-sm border mb-8 animate-in fade-in duration-500">
      <form id="processor-form" phx-change="validate" phx-submit="start_processing" class="space-y-8">

        <%!-- UPLOAD ERRORS --%>
        <%= for err <- upload_errors(@uploads.files_input) do %>
          <div class="mb-4 p-3 bg-red-50 border border-red-100 text-red-600 text-xs font-bold rounded-lg flex items-center gap-2 animate-in shake duration-300">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
            </svg>
            <%= Phoenix.Naming.humanize(err) %> (Max 20 files, 10MB each)
          </div>
        <% end %>

        <%!-- DROP ZONE --%>
        <div class="space-y-4 mb-8">
          <label class="text-sm font-bold text-gray-700 uppercase tracking-wider">Source Files</label>
          <div
            class="relative border-2 border-dashed border-gray-200 rounded-2xl p-10 text-center hover:border-indigo-400 hover:bg-indigo-50/30 transition-all cursor-pointer group"
            phx-drop-target={@uploads.files_input.ref}
          >
            <div class="flex flex-col items-center">
              <div class="p-4 bg-gray-50 rounded-full group-hover:scale-110 transition-transform duration-300">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8 text-gray-400 group-hover:text-indigo-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 13h6m-3-3v6m5 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
              </div>
              <p class="mt-4 text-sm font-medium text-gray-600 italic">Drag and drop your files here</p>
              <.live_file_input upload={@uploads.files_input} class="absolute inset-0 w-full h-full cursor-pointer opacity-0" />
              <p class="text-indigo-600 font-bold mt-2 text-sm">Click to browse or drag files here</p>
            </div>
          </div>

          <%!-- UPLOAD QUEUE --%>
          <div
            id="upload-queue"
            class="space-y-2 mt-4 max-h-[400px] overflow-y-auto pr-2 scrollbar-visible"
          >
            <%= for entry <- @uploads.files_input.entries do %>
              <div id={"entry-#{entry.ref}"} class="flex items-center justify-between p-3 bg-white border border-gray-100 rounded-xl shadow-sm animate-in slide-in-from-left-2">
                <div class="flex items-center gap-3">
                  <span class="text-xs font-bold px-2 py-0.5 bg-indigo-50 text-indigo-700 rounded uppercase">
                    <%= Path.extname(entry.client_name) |> String.replace(".", "") %>
                  </span>
                  <span class="text-sm font-medium text-gray-700"><%= entry.client_name %></span>
                </div>
                <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} class="text-gray-400 hover:text-red-500">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                  </svg>
                </button>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- ENGINE CONFIGURATION --%>
        <div class="grid grid-cols-1 gap-3">
          <%= for {mode_val, title, desc} <- [{:sequential, "Sequential", "Process file by file"}, {:parallel, "Parallel", "Process using Elixir processes"}, {:benchmark, "Benchmark", "Compares modes"}] do %>
            <label class={"relative flex flex-col p-4 border-2 rounded-xl cursor-pointer transition-all #{if @mode == mode_val, do: "border-blue-500 bg-blue-50/50 shadow-sm", else: "border-gray-100 hover:border-gray-200"}"}>
              <input type="radio" name="mode" value={mode_val} checked={@mode == mode_val} class="sr-only" />
              <span class="font-bold text-gray-800"><%= title %></span>
              <span class="text-xs text-gray-400 mt-1"><%= desc %></span>
            </label>
          <% end %>
        </div>

        <%!-- CONFIGURATION INPUTS --%>
        <div
          :if={@mode != :sequential}
          class={["grid gap-6 pt-4 animate-in fade-in slide-in-from-top-2",
                  if(@mode == :benchmark, do: "grid-cols-3", else: "grid-cols-2")]}
        >
          <div class="space-y-2">
            <label class="block text-sm font-bold text-gray-700 uppercase tracking-widest">Max Workers</label>
            <input type="number" name="workers" value="4" min="1" max="100" class="w-full px-4 py-3 rounded-xl border border-gray-300 bg-gray-50/50 text-gray-900 outline-none focus:ring-2 focus:ring-indigo-500 transition-all" />
          </div>

          <div class="space-y-2">
            <label class="block text-sm font-bold text-gray-700 uppercase tracking-widest">Timeout (ms)</label>
            <input type="number" name="timeout" value="5000" step="500" class="w-full px-4 py-3 rounded-xl border border-gray-300 bg-gray-50/50 text-gray-900 outline-none focus:ring-2 focus:ring-indigo-500 transition-all" />
          </div>

          <div :if={@mode == :benchmark} class="space-y-2 animate-in zoom-in-95 duration-300">
            <label class="block text-sm font-bold text-gray-700 uppercase tracking-widest">Visual Delay (ms)</label>
            <input type="number" name="visual_delay" value="0" min="0" step="50" class="w-full px-4 py-3 rounded-xl border border-gray-300 bg-gray-50/50 text-gray-900 outline-none focus:ring-2 focus:ring-indigo-500 transition-all" />
          </div>
        </div>

        <%!-- SUBMIT BUTTON --%>
        <button
          type="submit"
          disabled={@processing_started or Enum.empty?(@uploads.files_input.entries)}
          class="w-full mt-6 py-4 bg-indigo-600 text-white font-bold rounded-xl shadow-lg hover:bg-indigo-700 active:scale-[0.98] transition-all disabled:opacity-50"
        >
          <%= if @processing_started, do: "Analyzing Files...", else: "Start File Analysis" %>
        </button>
      </form>
    </div>
    <% end %>
    """
  end
end
