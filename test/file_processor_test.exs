defmodule FileProcessorTest do
  use ExUnit.Case

  setup do
    on_exit(fn ->
      "output/*generated_for_tests*"
      |> Path.wildcard()
      |> Enum.each(&File.rm!/1)
    end)

    %{
      valid_files: [
        "data/valid/ventas_enero.csv",
        "data/valid/usuarios.json",
        "data/valid/aplicacion.log"
      ],
      non_existent_file: "data/valid/non_existent_file.csv",
      non_existent_directory: "data/valid/non_existent_directory/",
      config: %{report_name_label: "generated_for_tests"},
      initial_metrics: FileProcessor.set_initial_metrics_map(),
      csv_result: {:ok, :csv, "ventas.csv", %{total_sales: 1000}},
      json_result: {:ok, :json, "usuarios.json", %{total_users: 50}},
      log_result: {:ok, :log, "aplicacion.log", %{total_entries: 300}}
    }
  end

  describe "process_files" do
    test "sequential processing completes successfully", %{valid_files: valid_files, config: config} do
      assert {:ok, message} = FileProcessor.process_files(:sequential, :list, valid_files, config)
      assert message =~ "Report generated successfully"
    end

    test "parallel processing completes successfully", %{valid_files: valid_files, config: config} do
      assert {:ok, message} = FileProcessor.process_files(:parallel, :list, valid_files, config)
      assert message =~ "Report generated successfully"
    end

    test "benchmark mode processing completes successfully", %{valid_files: valid_files, config: config} do
      assert {:ok, message} = FileProcessor.process_files(:benchmark, :list, valid_files, config)
      assert message =~ "Report generated successfully"
    end

    test "handles non existent directories", %{non_existent_directory: non_existent_directory, config: config} do
      assert {:error, reason} = FileProcessor.process_files(:sequential, :directory, non_existent_directory, config)
      assert reason == "Directory not found"
    end
  end

  describe "process_path" do
    test "handles non existent file paths", %{non_existent_file: non_existent_file} do
      assert {:error, _file_name, reason} = FileProcessor.process_path(non_existent_file)
      assert reason == "File not found"
    end

    test "handles non string arguments" do
      assert {:error, _file_name, reason} = FileProcessor.process_path(:file)
      assert reason == "Invalid argument, expected a string path"
    end
  end

  describe "update_metrics_map/2" do
    test "adds CSV result correctly", %{initial_metrics: metrics, csv_result: csv_result} do
      updated = FileProcessor.update_metrics_map(metrics, csv_result)
      assert [%{file: "ventas.csv", metrics: %{total_sales: 1000}}] = updated.csv
    end

    test "adds JSON result correctly", %{initial_metrics: metrics, json_result: json_result} do
      updated = FileProcessor.update_metrics_map(metrics, json_result)
      assert [%{file: "usuarios.json", metrics: %{total_users: 50}}] = updated.json
    end

    test "adds LOG result correctly", %{initial_metrics: metrics, log_result: log_result} do
      updated = FileProcessor.update_metrics_map(metrics, log_result)
      assert [%{file: "aplicacion.log", metrics: %{total_entries: 300}}] = updated.log
    end


    test "adds error correctly", %{initial_metrics: metrics} do
      updated = FileProcessor.update_metrics_map(metrics, {:error, "bad.csv", "File not found"})
      assert [%{file: "bad.csv", reason: "File not found"}] = updated.errors
    end
  end
end
