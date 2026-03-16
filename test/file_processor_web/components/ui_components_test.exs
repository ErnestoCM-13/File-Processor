defmodule FileProcessorWeb.UIComponentsTest do
  use FileProcessorWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  import FileProcessorWeb.UploadFormComponent
  import FileProcessorWeb.SuccessToastComponent

  test "UploadForm is hidden during processing" do
    assigns = %{
      processing_started: true,
      all_done: false,
      uploads: %{files_input: %{entries: [], ref: "ref"}},
      mode: :sequential
    }

    html = rendered_to_string(~H"""
      <.upload_form
        processing_started={@processing_started}
        all_done={@all_done}
        uploads={@uploads}
        mode={@mode}
      />
    """)

    assert String.trim(html) == ""
  end

  test "SuccessToast displays correct metrics when active" do
    assigns = %{
      show_toast: true,
      total_rows: 5,
      mode: :parallel,
      stats: %{},
      all_done: true
    }

    html = rendered_to_string(~H"""
      <.success_toast
        show_toast={@show_toast}
        total_rows={@total_rows}
        mode={@mode}
        stats={@stats}
        all_done={@all_done}
      />
    """)

    assert html =~ "File processing Complete"
    assert html =~ "Files processed"
  end
end
