defmodule FileProcessor.Core.Metrics do
  @moduledoc """
  Central structure used to accumulate processing results.

  This module defines the metrics structure used across the system to
  collect results produced during file processing.

  It stores:
  - Metrics grouped by file type (`csv`, `json`, `log`)
  - Processing errors
  - Execution metadata
  - Benchmark performance data
  - Generated report
  """

  defstruct [
    csv: [],
    json: [],
    log: [],
    errors: [],
    performance: %{},
    processes_used: 0,
    max_workers: 0,
    process_mode: "",
    process_config: %{},
    executive_summary: %{},
    report: ""
  ]

  # ----------------------------------------------------------------------
  # METRICS INITIALIZATION
  # ----------------------------------------------------------------------

  @doc """
  Creates a new empty metrics structure used to accumulate processing results.
  """
  def new, do: %__MODULE__{}

  # ----------------------------------------------------------------------
  # RESULT ACCUMULATION
  # ----------------------------------------------------------------------

  @doc """
  Updates the metrics structure with the result of a processed file..
  """
  def add_result(metrics, {:ok, file_type, file_name, file_result}) do
    existing_results = Map.get(metrics, file_type, [])

    updated_results = [
      %{
        file: file_name,
        metrics: file_result,
        internal_errors: Map.get(file_result, :error_lines, [])
      }
      | existing_results
    ]

    %{metrics | file_type => updated_results}
  end

  def add_result(metrics, {:error, file_name, reason}) do
    updated_results = [
      %{
        file: file_name,
        reason: reason
      }
      | metrics.errors
    ]

    %{metrics | errors: updated_results}
  end

  # ----------------------------------------------------------------------
  # METADATA HANDLING
  # ----------------------------------------------------------------------

  @doc """
  Adds execution metadata to the metrics structure.

  ## Parameters
  - `process_mode`:
      Execution strategy used (`:sequential`, `:parallel`, or `:benchmark`)
  - `config`:
      Configuration used during processing (`max_workers`, `timeout`).
  """
  def add_metadata(metrics, {process_mode, config}) do
    %{metrics |
      process_mode: Atom.to_string(process_mode),
      process_config: config
    }
  end

  @doc """
  Adds benchmark performance information to the metrics structure.
  """
  def add_performance_data(metrics, performance_data) do
    %{metrics | performance: performance_data}
  end
end
