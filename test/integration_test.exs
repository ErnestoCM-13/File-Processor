defmodule FileProcessor.IntegrationTest do
  use ExUnit.Case

  @valid_files [
    "data/valid/ventas_enero.csv",
    "data/valid/usuarios.json",
    "data/valid/aplicacion.log"
  ]

  @files_with_errors [
    "data/valid/ventas_enero.csv",
    "data/error/ventas_corrupto.csv",
    "data/error/usuarios_malformado.json"
  ]

  test "sequential processing completes successfully" do
    {:ok, message} =
      FileProcessor.process_files(
        :sequential,
        :list,
        @valid_files,
        %{timeout: 10_000, retries: 0}
      )

    assert message =~ "Report generated succesfully"
  end

  test "parallel processing completes with partial errors" do
    {:ok, message} =
      FileProcessor.process_files(
        :parallel,
        :list,
        @files_with_errors,
        %{timeout: 10_000, retries: 0}
      )

    assert message =~ "Report generated succesfully"
  end
end
