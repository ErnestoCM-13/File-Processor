defmodule FileProcessor.Executable do
  @moduledoc """
  Command Line Interface (CLI) handler for the FileProcessor.
  This module is responsible for:
  - Parsing terminal arguments.
  - Setting up global configuration based on user input.
  - Determining the execution mode (sequential, parallel, benchmark).
  - Dispatching the file or directory processing to the `FileProcessor` module.
  - Formatting and displaying results or errors to the console.
  """

  # ----------------------------------------------------------------------
  # PUBLIC ENTRY POINT
  # ----------------------------------------------------------------------

  @doc """
  Main entry point for the CLI executable.

  ## Parameters
  - `cli_arguments`: A list of strings representing the CLI arguments.

  ## Supported Options
  - `--dir` / `-d`: Directory path to process.
  - `--files` / `-f`: Enables processing of a list of files passed as arguments.
  - `--parallel` / `-p`: Enables parallel processing mode.
  - `--benchmark` / `-b`: Enable benchmark mode for performance measurement.
  - `--timeout` / `-t`: Set a custom execution timeout in milliseconds.
  - `--help` / `-h`: Show the help guide.
  """
  def main(cli_arguments) do
    {options, path_files_arguments, _invalid_options} =
      OptionParser.parse(cli_arguments,
        switches: [
          dir: :string,
          files: :boolean,
          parallel: :boolean,
          benchmark: :boolean,
          help: :boolean,
          timeout: :integer
        ],
        aliases: [
          p: :parallel,
          b: :benchmark,
          f: :files,
          d: :dir,
          h: :help,
          t: :timeout
        ]
      )

    # ----------------------------------------------------------------------
    # CONFIGURATION BUILDING
    # ----------------------------------------------------------------------

    # Set global configuration
    config = %{
      timeout: options[:timeout] || 10_000,
      # TODO: retries option is not currently exposed vía CLI
      retries: options[:retries] || 2
    }

    # ----------------------------------------------------------------------
    # EXECUTION MODE
    # ----------------------------------------------------------------------

    # Determine the mode of execution
    processing_mode = cond do
      options[:benchmark] -> :benchmark
      options[:parallel] -> :parallel
      true -> :sequential
    end

    # ----------------------------------------------------------------------
    # COMMAND ROUTING
    # ----------------------------------------------------------------------

    # Dispatch processing based on CLI options
    cond do
      options[:help] ->
        print_help_menu()

      options[:dir] ->
        directory_path = options[:dir]
        IO.puts("\nProcessing directory")
        FileProcessor.process_files(processing_mode, :directory, directory_path, config)
        |> format_and_display_response()

      options[:files] ->
        IO.puts("\nProcessing files")
        FileProcessor.process_files(processing_mode, :list, path_files_arguments, config)
        |> format_and_display_response()

      true ->
        IO.puts("\nError: Invalid command or missing arguments.")
        IO.puts("Use --help or -h to see the available options.\n")
    end
  end

  # ----------------------------------------------------------------------
  # HANDLE RESPONSE
  # ----------------------------------------------------------------------

  @doc false
  # Handles the system response for the file processing and prints it to the console
  defp format_and_display_response({:ok, message}), do: IO.puts("\n #{message}")
  defp format_and_display_response({:error, reason}), do: IO.puts("\n Error: #{reason}")
  defp format_and_display_response(other), do: IO.inspect(other)

  # ----------------------------------------------------------------------
  # HELP MENU
  # ----------------------------------------------------------------------

  @doc false
  # Prints the CLI usage guide and examples
  defp print_help_menu do
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
