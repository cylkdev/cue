defmodule Cue do
  @moduledoc ~S"""
  You can start the schedulers directly:

      Cue.start_link([Cue.schedulers.Oban])

  You can also add it to your supervision tree:

      def init(_) do
        children = [
          {Cue, [Cue.schedulers.Oban]}
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

  alias Cue.Adapter

  @default_adapter Cue.Adapters.Oban
  @default_name __MODULE__

  def start_link(schedulers, opts \\ []) do
    Supervisor.start_link(__MODULE__, schedulers, Keyword.put_new(opts, :name, @default_name))
  end

  def child_spec({schedulers, opts}) do
    %{
      id: {__MODULE__, opts[:id] || opts[:name] || opts[:key] || :default},
      start: {__MODULE__, :start_link, [schedulers, opts]},
      type: :supervisor,
      restart: Keyword.get(opts, :restart, :permanent),
      shutdown: Keyword.get(opts, :shutdown, 5_000)
    }
  end

  def child_spec(list) do
    cond do
      list === [] -> child_spec({[], []})
      Keyword.keyword?(list) -> list |> Keyword.pop(:schedulers, []) |> child_spec()
      true -> child_spec({list, []})
    end
  end

  @impl true
  def init(schedulers) do
    schedulers
    |> Enum.map(fn
      {adapter, child_spec_args} -> {adapter, child_spec_args}
      adapter -> {adapter, []}
    end)
    |> Enum.reduce([], fn {adapter, child_spec_args}, acc ->
      [adapter.child_spec(child_spec_args) | acc]
    end)
    |> Enum.reverse()
    |> Supervisor.init(strategy: :one_for_one)
  end

  def schedule_job(worker, params, delay_sec_or_datetime, opts) do
    opts
    |> scheduler()
    |> Adapter.schedule_job(worker, params, delay_sec_or_datetime, opts)
  end

  def add_job(params, opts \\ []) do
    opts
    |> scheduler()
    |> Adapter.add_job(params, opts)
  end

  def add_jobs(params, opts \\ []) do
    opts
    |> scheduler()
    |> Adapter.add_jobs(params, opts)
  end

  defp scheduler(opts) do
    opts[:scheduler] || @default_adapter
  end
end
