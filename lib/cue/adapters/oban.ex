defmodule Cue.Adapters.Oban do
  @moduledoc """
  # Cue.Oban

  `Cue.Oban` provides a standardized API for enqueuing jobs using Oban.
  This removes the need for boilerplate by providing custom wrapper
  functions and keeps call sites consistent and readable.
  """
  @behaviour Cue.Adapter

  @default_name __MODULE__

  @default_options [
    name: @default_name,
    repo: Cue.Repo,
    queues: [default: 5],
    plugins: []
  ]

  @definition [
    name: [
      type: :atom,
      required: true,
      doc:
        "The name used for the Oban supervisor registration, it must be unique across an entire VM instance."
    ],
    node: [
      type: :any,
      doc: "Node identifier used for multi-node coordination."
    ],
    engine: [
      type: :atom,
      default: Oban.Engines.Basic,
      doc: "The Oban engine module to use for job execution."
    ],
    notifier: [
      type: :atom,
      default: Oban.Notifiers.PG,
      doc: "The notifier module responsible for pub/sub notifications."
    ],
    peer: [
      type: :atom,
      default: Oban.Peers.Global,
      doc: "The peer module that coordinates leadership across nodes."
    ],
    repo: [
      type: :atom,
      required: true,
      doc: "The Ecto repo module used for database interactions."
    ],
    queues: [
      type: :keyword_list,
      doc: "Keyword list mapping queue names to concurrency values, e.g. `[default: 10]`."
    ],
    log: [
      type: :atom,
      doc: "Log level for Oban internal events."
    ],
    testing: [
      type: :atom,
      doc: "Mode for testing: `:inline` executes jobs immediately, `:disabled` ignores jobs."
    ],
    plugins: [
      type: :keyword_list,
      doc: "List of Oban plugins to load, e.g. `[Oban.Plugins.Pruner]`."
    ],
    prefix: [
      type: :string,
      doc: "The query prefix, or schema, to use for inserting and executing jobs."
    ]
  ]

  @doc false
  def definition, do: @definition

  @doc """
  Cue.Adapters.Oban.start_link()
  """
  def start_link(name \\ @default_name, opts \\ []) do
    oban_config = Cue.Config.get_env(__MODULE__) || Cue.Config.get_env(Oban) || []

    @default_options
    |> Keyword.merge(oban_config)
    |> Keyword.merge(opts)
    |> Keyword.put_new(:name, name)
    |> NimbleOptions.validate!(@definition)
    |> dbg()
    |> Oban.start_link()
  end

  def child_spec({name, opts}) do
    %{
      id: child_id(name),
      start: {__MODULE__, :start_link, [name, opts]},
      restart: Keyword.get(opts, :restart, :permanent),
      shutdown: Keyword.get(opts, :shutdown, 5_000),
      type: :worker
    }
  end

  def child_spec(opts) do
    opts
    |> Keyword.pop(:name, @default_name)
    |> child_spec()
  end

  defp child_id(__MODULE__), do: @default_name
  defp child_id(name), do: {__MODULE__, name}

  @impl true
  @doc """
  Cue.Adapters.Oban.schedule_job()
  """
  def schedule_job(
        %Oban.Job{args: args, worker: worker} = _job,
        params,
        delay_sec_or_datetime,
        opts
      ) do
    worker = string_to_module(worker)

    args
    |> Map.merge(params)
    |> worker.new(Keyword.merge(opts[:worker] || [], oban_schedule_opt(delay_sec_or_datetime)))
    |> Oban.insert(opts)
  end

  def schedule_job(worker, params, delay_sec_or_datetime, opts) do
    params
    |> worker.new(Keyword.merge(opts[:worker] || [], oban_schedule_opt(delay_sec_or_datetime)))
    |> Oban.insert(opts)
  end

  defp oban_schedule_opt(delay_sec_seconds)
       when is_integer(delay_sec_seconds) and delay_sec_seconds > 0 do
    [schedule_in: delay_sec_seconds]
  end

  defp oban_schedule_opt(%DateTime{} = datetime) do
    [schedule_at: datetime]
  end

  defp string_to_module(string) when is_binary(string) do
    string |> String.split(".", trim: true) |> Module.safe_concat()
  end

  defp string_to_module(term) do
    term
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
