defmodule Cue do
  @moduledoc ~S"""
  You can start the adapters directly:

      Cue.start_link([Cue.Adapters.Oban])

  You can also add it to your supervision tree:

      def init(_) do
        children = [
          {Cue, [Cue.Adapters.Oban]}
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

  @default_adapter Cue.Adapters.Oban
  @default_name __MODULE__

  def start_link(adapters \\ [@default_adapter], opts \\ []) do
    Supervisor.start_link(__MODULE__, adapters, Keyword.put_new(opts, :name, @default_name))
  end

  def child_spec({adapters, start_opts, sup_opts}) do
    %{
      id: {__MODULE__, start_opts[:id] || start_opts[:name] || start_opts[:key] || :default},
      start: {__MODULE__, :start_link, [adapters, start_opts]},
      type: :supervisor,
      restart: Keyword.get(sup_opts, :restart, :permanent),
      shutdown: Keyword.get(sup_opts, :shutdown, 5_000)
    }
  end

  def child_spec({adapters, start_opts}) do
    child_spec({adapters, start_opts, []})
  end

  def child_spec(adapters) do
    child_spec({adapters, [], []})
  end

  @impl true
  def init(adapters) do
    adapters
    |> Kernel.++(Cue.Config.adapters())
    |> List.flatten()
    |> Enum.map(fn
      {module, child_spec_args, opts} ->
        Supervisor.child_spec({module, child_spec_args}, opts)

      {module, child_spec_args} ->
        Supervisor.child_spec({module, child_spec_args}, [])

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
    opts[:scheduler] || @default_adapter
  end
end
