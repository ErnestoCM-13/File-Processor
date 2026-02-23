defmodule FileProcessor.ResultsCache do
  @moduledoc"""
  An Agent cache module for storing and getting file processing results using a unique identifier.
  """

  use Agent

  @doc """
  Starts the storage as an empty map linked to the current process.
  The Agent is registered under the module name (`__MODULE__`)
  """
  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc """
  Saves the processing results map associated with a unique ID.

  ## Parameters
  - `id`: A unique identifier for the results map.
  - `results`: The results map.
  """
  def put_processment_results(id, results) do
    Agent.update(__MODULE__, &Map.put(&1, id, results))
  end

  @doc """
  Gets the stored results for a given ID.

  Returns the results associated with the `id`, or `nil` if the ID
  does not exist in the cache.

  ## Parameters
  - `id`: The unique identifier used when the results were stored.
  """
  def get_processment_results(id) do
    Agent.get(__MODULE__, &Map.get(&1, id))
  end
end
