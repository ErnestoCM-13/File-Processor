defmodule FileProcessor.ExecutableTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  describe "main/1 CLI behavior" do
    test "shows help suggestion when invalid command is passed" do
      output = capture_io(fn ->
        FileProcessor.Executable.main([""])
      end)

      assert output =~ "Error: Invalid command or missing arguments."
      assert output =~ "Use --help or -h to see the available options."
    end

    test "shows help when --help is passed" do
      output = capture_io(fn ->
        FileProcessor.Executable.main(["--help"])
      end)

      assert output =~ "FILE PROCESSOR - USE GUIDE"
      assert output =~ "Available commands:"
      assert output =~ "Options:"
      assert output =~ "Examples:"
    end

    test "processes directory with --dir option" do
      output = capture_io(fn ->
        FileProcessor.Executable.main(["--dir", "data/directory", ])
      end)

      assert output =~ "Processing directory"
      assert output =~ "Error: Directory not found"
    end

    test "processes files list with --files option" do
      output = capture_io(fn ->
        FileProcessor.Executable.main(["--files", "file1.csv", "file2.csv"])
      end)

      assert output =~ "Processing files"
      assert output =~ "Report generated successfully: output/final_report_sequential_"
    end

    test "selects parallel mode when -p option is provided" do
      output = capture_io(fn ->
        FileProcessor.Executable.main(["--dir", "data/valid", "-p"])
      end)

      assert output =~ "Processing directory"
      assert output =~ "Progress:"
      assert output =~ "Report generated successfully: output/final_report_parallel_"
    end

    test "selects benchmark mode when -b option is provided" do
      output = capture_io(fn ->
        FileProcessor.Executable.main(["--dir", "data/valid", "-b"])
      end)

      assert output =~ "Processing directory"
      assert output =~ "Progress:"
      assert output =~ "Report generated successfully: output/final_report_benchmark_"
    end

    test "handles missing arguments" do
      output = capture_io(fn ->
        FileProcessor.Executable.main([])
      end)

      assert output =~ "Error: Invalid command or missing arguments"
      assert output =~ "Use --help or -h to see the available options"
    end
  end
end
