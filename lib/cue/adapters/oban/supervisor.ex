defmodule Cue.Adapters.Oban.Supervisor do
  @default_name __MODULE__
  @default_engine Oban.Engines.Basic
  @default_log :error
  @default_notifier Oban.Notifiers.PG
  @default_peer Oban.Peers.Global
  @default_queues [default: 10]
  @default_plugins [Oban.Plugins.Reindexer]
  @default_testing if Mix.env() === :test, do: :inline, else: :disabled
  @default_options [
    engine: @default_engine,
    notifier: @default_notifier,
    peer: @default_peer,
    queues: @default_queues,
    log: @default_log,
    testing: @default_testing,
    plugins: @default_plugins
  ]

  @definition [
    engine: [
      type: :atom,
      default: @default_engine,
      doc: "The engine module for executing jobs. Typically `Oban.Engines.Basic`."
    ],
    name: [
      type: :atom,
      default: @default_name,
      doc: "The process name for the Oban supervisor. Defaults to `Cue`."
    ],
    repo: [
      type: :atom,
      required: true,
      doc: "The Ecto repo module. Required."
    ],
    log: [
      type: :boolean,
      default: @default_log,
      doc: "Whether to enable logging for job lifecycle events."
    ],
    notifier: [
      type: :atom,
      default: @default_notifier,
      doc: "The PubSub module for notifying across nodes. Defaults to `Oban.Notifiers.PG`."
    ],
    plugins: [
      type: {:list, :any},
      default: @default_plugins,
      doc: "A list of plugins or `{plugin, opts}` tuples to start with Oban."
    ],
    peer: [
      type: :atom,
      default: @default_peer,
      doc: "The peer module for leader election. Defaults to `Oban.Peers.Global`."
    ],
    queues: [
      type: :keyword_list,
      default: @default_queues,
      doc: "A keyword list of queue names and their concurrency, e.g., `[default: 10]`."
    ],
    testing: [
      type: :atom,
      default: @default_testing,
      doc: "Controls test behavior. Can be `:inline`, `:manual`, or `:disabled`."
    ]
  ]

  @doc """
  Starts an Oban supervisor.

  ## Options

  #{NimbleOptions.docs(@definition, nest_level: 2)}

  ## Example

      Cue.start_link(MyApp.Oban, repo: MyApp.Repo)
  """
  @spec start_link(atom(), keyword()) :: Supervisor.on_start()
  def start_link(name \\ @default_name, opts \\ []) do
    @default_options
    |> Keyword.merge(opts)
    |> Keyword.put(:name, name)
    |> NimbleOptions.validate!(@definition)
    |> Oban.start_link()
  end

  @doc false
  def child_spec({name, opts}) do
    opts = Keyword.delete(opts, :name)

    %{
      id: name,
      start: {__MODULE__, :start_link, [name, opts]}
    }
  end

  def child_spec(opts) do
    name = opts[:name] || @default_name
    opts = Keyword.delete(opts, :name)

    %{
      id: name,
      start: {__MODULE__, :start_link, [name, opts]}
    }
  end
end
