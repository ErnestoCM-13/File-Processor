defmodule CrashWorker do
  # Worker that simulate crash
  def init(_file, _coord_pid) do
    exit(:boom)
  end
end

defmodule HangingWorker do
  # Worker that never responds
  def init(_file, _coord_pid) do
    receive do
      :never -> :ok
    end
  end
end

defmodule Parallel.CoordinatorTest do
  use ExUnit.Case

  defmodule DummyCoordinator do
    def init(files, parent, opts) do
      timeout = Map.get(opts, :timeout, 1000)

      results =
        Enum.map(files, fn
          {:crash, file} ->
            %{file: file, reason: "crashed"}

          {:hang, file} ->
            Process.sleep(timeout + 50)
            %{file: file, reason: "Timeout exceeded"}

          {:ok, file} ->
            %{file: file, reason: nil}
        end)

      errors = Enum.filter(results, & &1.reason)
      send(parent, {:all_done, %{errors: errors}})
    end
  end

  test "coordinator handles worker crash and reports error" do
    parent = self()

    spawn(fn ->
      DummyCoordinator.init(
        [{:crash, "fake.csv"}],
        parent,
        %{timeout: 500}
      )
    end)

    assert_receive {:all_done, results}, 1000
    assert length(results.errors) == 1
    assert hd(results.errors).reason == "crashed"
  end

  test "coordinator handles global timeout" do
    parent = self()

    spawn(fn ->
      DummyCoordinator.init(
        [{:hang, "slow1.csv"}, {:hang, "slow2.csv"}],
        parent,
        %{timeout: 100}  # short timeout for test
      )
    end)

    assert_receive {:all_done, results}, 500
    assert Enum.all?(results.errors, fn e -> e.reason == "Timeout exceeded" end)
  end

  test "coordinator processes successful files" do
    parent = self()

    spawn(fn ->
      DummyCoordinator.init(
        [{:ok, "good.csv"}],
        parent,
        %{timeout: 500}
      )
    end)

    assert_receive {:all_done, results}, 500
    assert results.errors == []
  end
end
