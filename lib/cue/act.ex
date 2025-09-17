defmodule Cue.Act do
  @callback director :: term()
  @callback actor :: term()
  @callback config :: term()
  @callback add_job(params :: term()) :: {:ok, any()} | {:error, any()}
  @callback add_jobs(params_list :: list(term())) :: list(any()) | any()

  def director(adapter), do: adapter.director()

  def actor(adapter), do: adapter.actor()

  def config(adapter, opts) do
    actor(adapter).config(adapter, opts)
  end

  def add_job(adapter, params, opts) do
    adapter
    |> director()
    |> actor(adapter).add_job(params, config(adapter, opts))
  end

  def add_jobs(adapter, params_list, opts) do
    adapter
    |> director()
    |> actor(adapter).add_jobs(params_list, config(adapter, opts))
  end

  defmacro __using__(opts) do
    director = Keyword.fetch!(opts, :director)
    actor = Keyword.fetch!(opts, :actor)

    quote do
      opts = unquote(opts)

      alias Cue.Act

      @behaviour Cue.Act

      @director unquote(director)
      @actor unquote(actor)
      @other_options Keyword.drop(opts, [:actor, :director])

      @impl Cue.Act
      def director, do: @director

      @impl Cue.Act
      def actor, do: @actor

      @impl Cue.Act
      def config do
        Act.config(__MODULE__, @other_options)
      end

      @impl Cue.Act
      def add_job(params) do
        Act.add_job(__MODULE__, params, @other_options)
      end

      @impl Cue.Act
      def add_jobs(params_list) do
        Act.add_jobs(__MODULE__, params_list, @other_options)
      end

      use unquote(actor), unquote(opts)
    end
  end
end
