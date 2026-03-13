defmodule FileProcessor do
  @moduledoc """
  Central orchestrator for the file processing system.

  It coordinates the full lifecycle of file processing by delegating
  responsibilities to specialized modules.

  Main responsibilities include:
  - Normalizing input sources (`directory`, explicit `list` or `%Plug.Upload` structure) into a
    standardized file structure.
  - Executing the processing workflow according to the selected
    execution mode (`Sequential`, `Parallel`, or `Benchmark`).
  - Collecting metrics produced during processing.
  - Sending the aggregated results to the report generator.
  """

  alias FileProcessor.Core.{Normalization, Metrics}
  alias FileProcessor.Execution.{Parallel, Sequential, Benchmark}
  alias FileProcessor.Report.Generator
  alias FileProcessor.Execution.Notifier

  # ----------------------------------------------------------------------
  # PUBLIC API
  # ----------------------------------------------------------------------

  @doc """
  Entry point of the file processing system.

  This function orchestrates the complete processing pipeline:
  1. Normalizes the input source into a standardized file list.
  2. Executes the processing flow according to the selected execution mode.
  3. Generates the final report.

  ## Parameters
  - `execution_mode`:
      An atom that determines how files are processed.
      Expected values: `:parallel`, `:sequential`, `:benchmark`.
  - `source_type`:
      An atom that indicates how file paths are provided.
      Expected values: `:directory`, `:list` or `%Plug.Upload`.
  - `input`:
      A directory path (string) when `source_type` is `:directory`,
      or a list of file paths (strings) or a %Plug.Upload structure list
      when `source_type` is `:list`.
  - `config`:
      Configuration map used during processing and report generation.
  """
  def process_files(execution_mode, source_type, input, config) do
    normalization = Map.get(config, :normalization_module, Normalization)
    generator = Map.get(config, :generator_module, Generator)

    files = normalization.normalize_entry(source_type, input)

    metrics = execute(execution_mode, files, config)

    final_results = generator.build(metrics, execution_mode, config)

    Notifier.broadcast_completition(final_results)

    final_results
  end

  # ----------------------------------------------------------------------
  # EXECUTION MODES
  # ----------------------------------------------------------------------

  @doc false
  # Dispatches execution to the corresponding execution module.
  defp execute(mode, files, config) do
    module = case mode do
      :sequential -> Map.get(config, :sequential_module, Sequential)
      :parallel   -> Map.get(config, :parallel_module, Parallel)
      :benchmark  -> Map.get(config, :benchmark_module, Benchmark)
    end
    module.run(files, Metrics.new(), config)
  end
end
