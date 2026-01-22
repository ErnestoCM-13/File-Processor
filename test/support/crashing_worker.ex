defmodule TestSupport.CrashingWorker do
  # Worker that simulate crash
  def init(_file, _coordinator_pid) do
    exit(:boom)
  end
end
