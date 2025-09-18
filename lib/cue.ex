defmodule Cue do
  @moduledoc ~S"""
  You can start the adapters directly:

      Cue.start_link([{Cue.Adapters.Oban, name: ObanA}])

  You can also add it to your supervision tree:

      def init(_) do
        children = [
          {Cue, schedulers: [Cue.Adapters.Oban]}
        ]

        Supervisor.init(children, strategy: :one_for_one)
      end

  Once you've setup your scheduler you can now call the scheduler functions,
  for example:

      defmodule Greeter do
        use Oban.Worker

        @impl true
        def  perform(%Oban.Job{args: %{"name" => name, "message" => message}}) do
          IO.puts("#{message}, #{name}.")
          :ok
        end
      end

  Cue.add_job(%{name: "Alice", message: "Hello"}, oban: [name: ObanA, worker: Greeter])
  Cue.add_jobs([%{name: "Alice", message: "Hello"}], oban: [name: ObanA, worker: Greeter])
  """
  use Supervisor

  @default_scheduler Cue.Adapters.Oban
  @default_name __MODULE__

  def start_link(schedulers, opts \\ []) do
    Supervisor.start_link(__MODULE__, schedulers, Keyword.put_new(opts, :name, @default_name))
  end

  def child_spec({schedulers, child_opts, start_opts}) do
    Supervisor.child_spec({__MODULE__, [schedulers, start_opts]}, child_opts)
  end

  def child_spec({schedulers, opts}) do
    child_opts = Keyword.get(opts, :supervisor, [])
    start_opts = Keyword.drop(opts, [:schedulers, :supervisor])

    child_spec({schedulers, child_opts, start_opts})
  end

  def child_spec(opts) do
    schedulers = Keyword.get(opts, :schedulers, [])
    child_opts = Keyword.get(opts, :supervisor, [])
    start_opts = Keyword.drop(opts, [:schedulers, :supervisor])

    child_spec({schedulers, child_opts, start_opts})
  end

  @impl true
  def init(schedulers) do
    schedulers
    |> Kernel.++(Cue.Config.schedulers())
    |> List.flatten()
    |> Enum.map(fn
      {module, args, opts} ->
        Supervisor.child_spec({module, args}, opts)

      {module, args} ->
        Supervisor.child_spec({module, args}, [])

      module ->
        Supervisor.child_spec(module, [])
    end)
    |> Enum.reduce(MapSet.new(), fn entry, set -> MapSet.put(set, entry) end)
    |> MapSet.to_list()
    |> Supervisor.init(strategy: :one_for_one)
  end

  def add_job(params, opts \\ []) do
    scheduler(opts).add_job(params, opts)
  end

  def add_jobs(params, opts \\ []) do
    scheduler(opts).add_jobs(params, opts)
  end

  defp scheduler(opts) do
    opts[:scheduler] || @default_scheduler
  end
end
