defmodule Cue.Retry do
  @callback perform(any(), function(), any()) :: any()

  def perform(adapter, job, fun, policy) do
    adapter.perform(job, fun, policy)
  end
end
