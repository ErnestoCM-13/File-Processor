# lib/file_processor_web/controllers/error_html.ex
defmodule FileProcessorWeb.ErrorHTML do
  use FileProcessorWeb, :html

  # This maps all .heex files inside the error_html directory
  embed_templates "error_html/*"
end
