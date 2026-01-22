defmodule FileProcessorTest do
  use ExUnit.Case

  setup do
    %{
      valid_files: [
        "data/valid/ventas_enero.csv",
        "data/valid/usuarios.json",
        "data/valid/aplicacion.log"
      ]
    }
  end

  describe "process_files" do
    test "sequential processing completes successfully", %{valid_files: valid_files} do
      assert {:ok, message} = FileProcessor.process_files(:sequential, :list, valid_files, %{})
      assert message =~ "Report generated successfully"
    end

    test "parallel processing completes successfully", %{valid_files: valid_files} do
      assert {:ok, message} = FileProcessor.process_files(:parallel, :list, valid_files, %{})
      assert message =~ "Report generated successfully"
    end

    test "benchmark mode processing completes successfully", %{valid_files: valid_files} do
      assert {:ok, message} = FileProcessor.process_files(:benchmark, :list, valid_files, %{})
      assert message =~ "Report generated successfully"
    end
  end
end
