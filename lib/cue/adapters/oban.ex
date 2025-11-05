defmodule Cue.Adapters.Oban do
  @moduledoc """
  # Cue.Oban

  `Cue.Oban` provides a standardized API for enqueuing jobs using Oban.
  This removes the need for boilerplate by providing custom wrapper
  functions and keeps call sites consistent and readable.
  """
  @behaviour Cue.Adapter

  @default_name __MODULE__
  @default_repo if(Mix.env() === :test, do: Cue.Support.Repo)
  @default_testing if(Mix.env() === :test, do: :inline, else: :disabled)
  @default_queues [default: 10]
  @default_options [
    engine: Oban.Engines.Basic,
    notifier: Oban.Notifiers.PG,
    peer: Oban.Peers.Global,
    repo: @default_repo,
    queues: @default_queues,
    log: :error,
    testing: @default_testing,
    plugins: []
  ]

  @definition [
    name: [
      type: :atom,
      default: @default_name,
      doc:
        "The name used for the Oban supervisor registration, it must be unique across an entire VM instance."
    ],
    node: [
      type: :any,
      doc: "Node identifier used for multi-node coordination."
    ],
    engine: [
      type: :any,
      default: Oban.Engines.Basic,
      doc: "The Oban engine module to use for job execution."
    ],
    notifier: [
      type: :any,
      default: Oban.Notifiers.PG,
      doc: "The notifier module responsible for pub/sub notifications."
    ],
    peer: [
      type: :any,
      default: Oban.Peers.Global,
      doc: "The peer module that coordinates leadership across nodes."
    ],
    repo: [
      type: :any,
      required: true,
      doc: "The Ecto repo module used for database interactions."
    ],
    queues: [
      type: :any,
      default: @default_queues,
      doc: "Keyword list mapping queue names to concurrency values, e.g. `[default: 10]`."
    ],
    log: [
      type: :any,
      default: :error,
      doc: "Log level for Oban internal events."
    ],
    testing: [
      type: :any,
      doc: "Mode for testing: `:inline` executes jobs immediately, `:disabled` ignores jobs."
    ],
    plugins: [
      type: :any,
      default: [],
      doc: "List of Oban plugins to load, e.g. `[Oban.Plugins.Pruner]`."
    ],
    prefix: [
      type: :any,
      doc: "The query prefix, or schema, to use for inserting and executing jobs."
    ]
  ]

  @doc false
  def definition, do: @definition

  @doc """
  Cue.Adapters.Oban.start_link()
  """
  def start_link(opts \\ []) do
    @default_options
    |> Keyword.merge(Cue.Config.get_app_env(:oban, []))
    |> Keyword.merge(opts)
    |> Keyword.put_new(:name, @default_name)
    |> NimbleOptions.validate!(@definition)
    |> Oban.start_link()
  end

  def child_spec(opts \\ []) do
    %{
      id: {__MODULE__, opts[:id] || opts[:name] || opts[:key] || :default},
      start: {__MODULE__, :start_link, [opts]},
      restart: Keyword.get(opts, :restart, :permanent),
      shutdown: Keyword.get(opts, :shutdown, 5_000),
      type: :worker
    }
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

    case opts[:oban][:module] do
      nil ->
        name = opts[:oban][:name] || @default_name
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
  @spec add_jobs(
          map()
          | Ecto.Changeset.t()
          | Oban.Job.t()
          | list(map() | Ecto.Changeset.t() | Oban.Job.t()),
          keyword()
        ) ::
          list(Oban.Job.t()) | Ecto.Multi.t()
  def add_jobs(params, opts) do
    params_list = List.wrap(params)
    changesets = to_changeset(params_list, opts)

    case opts[:oban][:module] do
      nil ->
        name = opts[:oban][:name] || @default_name
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
