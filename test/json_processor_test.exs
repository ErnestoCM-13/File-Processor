defmodule FileProcessor.JsonProcessorTest do
  use ExUnit.Case

  test "processes valid JSON file" do
    {:ok, metrics} =
      FileProcessor.JsonProcessor.process("data/valid/usuarios.json")

    assert metrics.total_users == 10
    assert metrics.total_sessions == 10
    assert metrics.errors_found == 0
  end

  test "handles malformed JSON without crashing" do
    {:ok, metrics} =
      FileProcessor.JsonProcessor.process("data/error/usuarios_sucio.json")

    assert metrics.errors_found > 0
    assert is_list(metrics.error_details)
  end
end
