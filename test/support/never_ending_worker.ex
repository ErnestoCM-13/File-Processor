defmodule TestSupport.NeverEndingWorker do
  # Worker that never responds
  def init(_file_info, _coordinator_pid) do
    loop()
  end

  defp loop do
    # Keeps the process alive without sending any response
    Process.sleep(:infinity)
    loop()
  end
end
