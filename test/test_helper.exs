#File.ls!("test/support")
#|> Enum.each(fn file ->
#  if String.ends_with?(file, ".ex"), do: Code.require_file("test/support/#{file}")
#end)
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(FileProcessor.Repo, :manual)
