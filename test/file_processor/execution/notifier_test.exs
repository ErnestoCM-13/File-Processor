defmodule FileProcessor.Execution.NotifierTest do
  use FileProcessorWeb.ConnCase, async: true
  alias FileProcessor.Execution.Notifier

  @topic "notifier_tests"

  describe "broadcast_file_progress/6" do
    test "sends the correct message for files processed" do
      FileProcessorWeb.Endpoint.subscribe(@topic)

      result = {:ok, :csv, "test.csv", %{invalid_lines: 0}}
      Notifier.broadcast_file_progress(:parallel, "test.csv", result, 1, 1, %{}, @topic)

      assert_receive %Phoenix.Socket.Broadcast{
        event: "file_processed",
        payload: %{
          mode: :parallel,
          name: "test.csv",
          status: :ok,
          current: 1,
          total: 1
        }
      }
    end

    test "sends the correct message for processment completition" do
      FileProcessorWeb.Endpoint.subscribe(@topic)

      files = ["file_1", "file_2"]
      result = {:ok, :csv, "test.csv", %{invalid_lines: 0}}
      Notifier.broadcast_completition(result, files, %{}, @topic)

      assert_receive %Phoenix.Socket.Broadcast{
        event: "all_done",
        payload: %{results: {:ok, :csv, "test.csv", %{invalid_lines: 0}}}
      }

    end
  end
end
