defmodule Cue.Oban.Performer do
  alias Cue.Director

  defstruct [:source, :instance, :name, :params, :options]

  @callback handle_perform(job :: term(), config :: term()) :: term()

  def config(source, opts) do
    %__MODULE__{
      source: source,
      instance: opts[:oban][:instance],
      name: opts[:oban][:name] || Cue.Oban,
      params: Keyword.get(opts, :params, %{}),
      options: Keyword.get(opts, :options, [])
    }
  end

  def handle_perform(adapter, job) do
    adapter.handle_perform(job, adapter.config())
  end

  def add_job(director, params, %__MODULE__{} = config) do
    Director.add_job(
      director,
      Map.merge(config.params, params),
      options_for(config)
    )
  end

  def add_jobs(director, params_list, %__MODULE__{} = config) do
    Director.add_jobs(
      director,
      Enum.map(params_list, &Map.merge(config.params, &1)),
      options_for(config)
    )
  end

  defp options_for(%__MODULE__{options: opts} = config) do
    opts
    |> Keyword.put_new(:oban, [])
    |> Keyword.update!(:oban, fn oban_opts ->
      if config.instance do
        oban_opts
        |> Keyword.put(:worker, config.source)
        |> Keyword.put_new(:instance, config.instance)
      else
        oban_opts
        |> Keyword.put(:worker, config.source)
        |> Keyword.put_new(:name, config.name)
      end
    end)
  end

  defmacro __using__(opts) do
    quote do
      opts = unquote(opts)

      use Oban.Worker,
          Keyword.take(unquote(opts), [
            :max_attempts,
            :priority,
            :queue,
            :tags,
            :replace,
            :unique
          ])

      alias Cue.Oban.Performer

      @behaviour Cue.Oban.Performer

      @impl Oban.Worker
      def perform(job) do
        Performer.handle_perform(__MODULE__, job)
      end
    end
  end
end
