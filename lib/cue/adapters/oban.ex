defmodule Cue.Adapters.Oban do
  @behaviour Cue.Adapter

  alias Cue.Adapters.Oban

  def start_link(name, opts \\ []) do
    Oban.Supervisor.start_link(name, opts)
  end

  def child_spec(args) do
    Oban.Supervisor.child_spec(args)
  end

  def add_job(params_or_changeset, opts \\ []) do
    Oban.API.insert(params_or_changeset, opts)
  end

  def add_jobs(params_or_changesets, opts \\ []) do
    Oban.API.insert_all(params_or_changesets, opts)
  end
end
