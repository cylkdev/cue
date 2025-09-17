defmodule Cue.Oban do
  @behaviour Cue.Director

  @default_name __MODULE__
  @testing if(Mix.env() === :test, do: :inline, else: :disabled)
  @default_options [
    engine: Oban.Engines.Basic,
    notifier: Oban.Notifiers.PG,
    peer: Oban.Peers.Global,
    repo: Cue.Support.Repo,
    queues: [default: 5],
    log: :error,
    testing: @testing,
    plugins: [Oban.Plugins.Reindexer]
  ]

  @doc """
  Cue.Oban.start_link()
  """
  def start_link(opts \\ []) do
    @default_options
    |> Keyword.merge(opts)
    |> Keyword.put_new(:name, @default_name)
    |> Oban.start_link()
  end

  def child_spec(opts \\ []) do
    opts = Keyword.merge(@default_options, opts)

    %{
      id: {__MODULE__, opts[:id] || opts[:name] || opts[:key] || :default},
      start: {__MODULE__, :start_link, [opts]},
      restart: Keyword.get(opts, :restart, :permanent),
      shutdown: Keyword.get(opts, :shutdown, 5_000),
      type: :worker
    }
  end

  def supervisor_child_spec(opts) do
    {__MODULE__, opts[:oban] || []}
  end

  @impl true
  @doc """
  Inserts a job using the provided parameters or changeset.

  ## Options

    * `:worker` — the Oban worker module (required unless passing a changeset)
    * `:oban` — options used to route to a specific instance or name

  Supports the same `:oban` options as `Oban.insert/3`.
  """
  @spec add_job(map() | Ecto.Changeset.t() | Oban.Job.t(), keyword()) ::
          {:ok, Oban.Job.t()} | {:error, term()}
  def add_job(params, opts) do
    changeset = to_changeset(params, opts)

    case opts[:oban][:instance] do
      nil ->
        name = opts[:oban][:name]

        if name === nil do
          raise "oban option :name is required, got: #{inspect(opts)}"
        end

        Oban.insert(name, changeset, opts)

      instance ->
        instance.insert(changeset, opts)
    end
  end

  @impl true
  @doc """
  Inserts multiple jobs using parameters or changesets.

  Supports the same `:oban` options as `Oban.insert_all/3`.
  """
  @spec add_jobs([map() | Ecto.Changeset.t() | Oban.Job.t()], keyword()) ::
          list(Oban.Job.t()) | Ecto.Multi.t()
  def add_jobs(params_list, opts) do
    changesets = to_changeset(params_list, opts)

    case opts[:oban][:instance] do
      nil ->
        name = opts[:oban][:name]

        if name === nil do
          raise "oban option :name is required, got: #{inspect(opts)}"
        end

        Oban.insert_all(name, changesets, opts)

      instance ->
        instance.insert_all(changesets, opts)
    end
  end

  defp to_changeset([_ | _] = entries, opts) do
    Enum.map(entries, &to_changeset(&1, opts))
  end

  defp to_changeset(%Oban.Job{args: args}, opts) do
    to_changeset(args, opts)
  end

  defp to_changeset(%Ecto.Changeset{} = changeset, _opts) do
    changeset
  end

  defp to_changeset(params, opts) do
    worker = opts[:oban][:worker]

    if worker === nil do
      raise "oban option :worker is required, got: #{inspect(opts)}"
    end

    worker.new(
      params,
      Keyword.take(opts[:oban][:job] || [], [
        :max_attempts,
        :meta,
        :priority,
        :queue,
        :replace,
        :schedule_in,
        :scheduled_at,
        :tags,
        :unique
      ])
    )
  end
end
