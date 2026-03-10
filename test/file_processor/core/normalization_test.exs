defmodule FileProcessor.Core.NormalizationTest do
  use ExUnit.Case, async: true

  alias FileProcessor.Core.Normalization

  # ---------------------------------------------------------------------------
  # TESTS
  # ---------------------------------------------------------------------------

  describe "normalize_entry/2 with :directory" do
    setup do
      tmp_dir = Path.join(System.tmp_dir!(), "norm_test")
      File.rm_rf!(tmp_dir)
      File.mkdir_p!(tmp_dir)
      File.write!(Path.join(tmp_dir, "file1.txt"), "content")
      File.write!(Path.join(tmp_dir, "file2.txt"), "content")
      %{tmp_dir: tmp_dir}
    end

    test "returns normalized list for existing directory", %{tmp_dir: tmp_dir} do
      result = Normalization.normalize_entry(:directory, tmp_dir)
      assert Enum.sort(result) == Enum.sort([
        {Path.join(tmp_dir, "file1.txt"), "file1.txt"},
        {Path.join(tmp_dir, "file2.txt"), "file2.txt"}
      ])
    end

    test "returns empty list for empty directory" do
      tmp_dir = Path.join(System.tmp_dir!(), "empty_norm_test")
      File.rm_rf!(tmp_dir)
      File.mkdir_p!(tmp_dir)
      assert Normalization.normalize_entry(:directory, tmp_dir) == []
    end

    test "returns error for non-existent directory" do
      assert {:error, "Directory not found"} =
        Normalization.normalize_entry(:directory, "/non/existent/dir")
    end
  end

  describe "normalize_entry/2 with :list" do
    test "normalizes a list of string paths" do
      file_list = ["/tmp/file1.csv", "/tmp/file2.log"]
      expected = [
        {"/tmp/file1.csv", "file1.csv"},
        {"/tmp/file2.log", "file2.log"}
      ]
      assert Normalization.normalize_entry(:list, file_list) == expected
    end

    test "normalizes a list of %Plug.Upload{} structs" do
      uploads = [
        %Plug.Upload{path: "/tmp/a.csv", filename: "a.csv"},
        %Plug.Upload{path: "/tmp/b.log", filename: "b.log"}
      ]
      expected = [
        {"/tmp/a.csv", "a.csv"},
        {"/tmp/b.log", "b.log"}
      ]
      assert Normalization.normalize_entry(:list, uploads) == expected
    end

    test "returns error for unsupported element" do
      invalid_list = [123, :atom, nil]
      assert Enum.all?(Normalization.normalize_entry(:list, invalid_list), fn
        {:error, _} -> true
        _ -> false
      end)
    end

    test "mixed valid and invalid entries" do
      input = [
        "/tmp/file.csv",
        %Plug.Upload{path: "/tmp/b.csv", filename: "b.csv"},
        123
      ]

      results = Normalization.normalize_entry(:list, input)

      assert {"/tmp/file.csv", "file.csv"} in results
      assert {"/tmp/b.csv", "b.csv"} in results
      assert Enum.any?(results, fn r -> match?({:error, _}, r) end)
    end
  end
end
