defmodule Cue.Adapters.Oban do
  alias Cue.Adapters.Oban.Core

  @behaviour Cue.Adapter

  def start_link(opts \\ []) do
    Core.start_link(opts)
  end

  @doc false
  def child_spec(opts) do
    Core.child_spec(opts)
  end

  def enqueue_job(params_or_changeset, opts) do
    Core.insert(params_or_changeset, opts)
  end

  def enqueue_jobs(params_or_changesets, opts) do
    Core.insert_all(params_or_changesets, opts)
  end
end
