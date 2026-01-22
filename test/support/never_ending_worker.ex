defmodule TestSupport.NeverEndingWorker do
  # Worker that never responds
  def init(_file, _coordinator_pid) do
    Process.sleep(:infinity)
  end
end
