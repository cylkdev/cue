defmodule Cue.Adapter do
  @callback add_job(term(), keyword()) :: {:ok, any()} | {:error, any()}
  @callback add_jobs(term(), keyword()) :: list(any()) | any()
  def add_job(adapter, input, opts), do: adapter.add_job(input, opts)
  def add_jobs(adapter, inputs, opts), do: adapter.add_jobs(inputs, opts)
end
