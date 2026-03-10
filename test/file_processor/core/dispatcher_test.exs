defmodule FileProcessor.Core.DispatcherTest do
  use ExUnit.Case, async: true

  alias FileProcessor.Core.Dispatcher
  alias FileProcessor.Formats.{Csv, Json, Log}

  # ---------------------------------------------------------------------------
  # TESTS
  # ---------------------------------------------------------------------------

  describe "get_processor/1" do
    test "returns Csv module for .csv (case insensitive)" do
      assert {:ok, Csv} == Dispatcher.get_processor(".csv")
      assert {:ok, Csv} == Dispatcher.get_processor(".CSV")
    end

    test "returns Json module for .json (case insensitive)" do
      assert {:ok, Json} == Dispatcher.get_processor(".json")
      assert {:ok, Json} == Dispatcher.get_processor(".JSON")
    end

    test "returns Log module for .log (case insensitive)" do
      assert {:ok, Log} == Dispatcher.get_processor(".log")
      assert {:ok, Log} == Dispatcher.get_processor(".LOG")
    end

    test "returns error for unsupported extensions" do
      assert {:error, msg} = Dispatcher.get_processor(".xml")
      assert msg =~ "Unsupported file format"

      assert {:error, msg} = Dispatcher.get_processor(".txt")
      assert msg =~ "Unsupported file format"
    end

    test "returns error for filenames without extension" do
      assert {:error, msg} = Dispatcher.get_processor("")
      assert msg =~ "Unsupported file format"
    end

    test "handles mixed case unsupported extension" do
      assert {:error, msg} = Dispatcher.get_processor(".XmL")
      assert msg =~ "Unsupported file format"
    end
  end
end
