defmodule Cue.Adapters.Oban.API do
  @oban_job_keys [
    :max_attempts,
    :meta,
    :priority,
    :queue,
    :replace,
    :schedule_in,
    :scheduled_at,
    :tags,
    :unique,
    :worker
  ]

  @doc """
  Inserts a job using the provided parameters or changeset.

  ## Options

    * `:worker` — the Oban worker module (required unless passing a changeset)
    * `:oban` — options used to route to a specific instance or name

  Supports the same `:oban` options as `Oban.insert/3`.

  ## Example

      Cue.insert(%{user_id: 1}, worker: MyApp.Worker)
  """
  @spec insert(map() | Ecto.Changeset.t(), keyword()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def insert(params_or_changeset, opts) do
    changeset = build_changeset(params_or_changeset, opts)

    if Keyword.has_key?(opts, :instance) do
      instance = Keyword.fetch!(opts, :instance)
      instance.insert(changeset, opts)
    else
      name = Keyword.fetch!(opts, :name)
      Oban.insert(name, changeset, opts)
    end
  end

  @doc """
  Inserts multiple jobs using parameters or changesets.

  Supports the same `:oban` options as `Oban.insert_all/3`.

  ## Example

      Cue.insert_all(
        [%{user_id: 1}, %{user_id: 2}],
        worker: MyApp.Worker,
        oban: [instance: MyApp.Oban]
      )
  """
  @spec insert_all([map() | Ecto.Changeset.t()], keyword()) ::
          {:ok, [Oban.Job.t()]} | {:error, term()}
  def insert_all(params_or_changesets, opts) do
    changesets = build_changesets(params_or_changesets, opts)

    if Keyword.has_key?(opts, :instance) do
      instance = Keyword.fetch!(opts, :instance)
      instance.insert_all(changesets, opts)
    else
      name = Keyword.fetch!(opts, :name)
      Oban.insert_all(name, changesets, opts)
    end
  end

  ## Helpers

  defp build_changesets([_ | _] = entries, opts) do
    Enum.map(entries, &build_changeset(&1, opts))
  end

  defp build_changeset(%Ecto.Changeset{} = changeset, _opts), do: changeset

  defp build_changeset(params, opts) do
    worker = Keyword.fetch!(opts, :worker)
    worker_opts = Keyword.take(opts, @oban_job_keys)
    worker.new(params, worker_opts)
  end
end
