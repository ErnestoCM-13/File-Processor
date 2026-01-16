defmodule FileProcessor.Executable do
  @moduledoc """
  Command Line Interface (CLI) handler for the FileProcessor.
  It parses terminal arguments, sets up global configuration, and
  dispatches the execution to the `FileProcessor` module.
  """

  @doc """
  Main entry point for the executable module.

  ## Parameters
  - `args`: A list of strings representing the CLI arguments.

  ## Options handled
  - `--dir` / `-d`: Directory to process.
  - `--files` / `-f`: List of files to process.
  - `--parallel` / `-p`: Enables parallel mode.
  - `--benchmark` / `-b`: Enables benchmark mode.
  - `--timeout` / `-t`: Sets execution timeout.
  """
  def main(args) do
    {options, remaining_args, _} = OptionParser.parse(args,
      switches: [
        dir: :string, files: :boolean, parallel: :boolean, benchmark: :boolean,
        help: :boolean, timeout: :integer
      ],
      aliases: [p: :parallel, b: :benchmark, f: :files, d: :dir, h: :help, t: :timeout]
    )

    config = %{
      timeout: options[:timeout] || 10_000,
      retries: options[:retries] || 2
    }

    mode = cond do
      options[:benchmark] -> :benchmark
      options[:parallel] -> :parallel
      true -> :sequential
    end

    cond do
      options[:help] ->
        print_help()

      options[:dir] ->
        path = options[:dir]
        IO.puts("\nProcessing directory")
        FileProcessor.process_files(mode, :directory, path, config) |> handle_response()

      options[:files] ->
        IO.puts("\nProcessing files")
        FileProcessor.process_files(mode, :list, remaining_args, config) |> handle_response()

      true ->
        IO.puts("\nError: Invalid command or missing arguments.")
        IO.puts("Use --help or -h to see the available options.\n")
    end
  end

  @doc false
  # Formats the final system response for the console.
  defp handle_response({:ok, message}), do: IO.puts("\n #{message}")
  defp handle_response({:error, reason}), do: IO.puts("\n Error: #{reason}")
  defp handle_response(other), do: IO.inspect(other)

  @doc false
  # Displays the help menu with examples.
  defp print_help do
    IO.puts("""
    =========================================
    FILE PROCESSOR - USE GUIDE
    =========================================
    Available commands:
      -f, --file <path>       Process a single file (always sequential).
      -d, --dir <path>        Process all files in a directory.
      --files <p1> <p2>...    Process a list of specific paths.

    Options:
      -t, --timeout <ms>      Set process timeout (default 10000).
      -p, --parallel          Enable parallel processing (for --dir or --files).
      -b, --benchmark         Enable benchmark mode (performance metrics).
      -h, --help              Show this help message.

    Examples:
      ./file_processor -d data/valid -b
      ./file_processor -f data/valid/ventas.csv
      ./file_processor --files data/valid/usuarios.json data/error/sistema_corrupto.log -p
    =========================================
    """)
  end
end
