defmodule FileProcessorWeb.PageControllerTest do
  use FileProcessorWeb.ConnCase

  # test/file_processor_web/controllers/page_controller_test.exs
  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "File Processor"
  end
end
