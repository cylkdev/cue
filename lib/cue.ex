defmodule Cue do
  @callback adapter() :: module()

  @callback add_job(any(), keyword()) :: {:ok, any()} | {:error, any()}
  @callback add_jobs(any(), keyword()) :: {:ok, [any()]} | {:error, any()}

  def add_job(adapter, args, opts) do
    adapter.add_job(args, opts)
  end

  def add_jobs(adapter, args, opts) do
    adapter.add_jobs(args, opts)
  end

  @adapter_definition [
    adapter: [
      required: true,
      type: :atom
    ]
  ]

  def validate_adapter_options!(opts) do
    NimbleOptions.validate!(opts, @adapter_definition)
  end

  def quoted_adapter_ast(opts) do
    quote do
      opts = unquote(opts)

      opts = Cue.validate_adapter_options!(opts)

      alias Cue.Adapter

      @behaviour Cue.Adapter

      @adapter Keyword.fetch!(opts, :adapter)

      def adapter, do: @adapter

      def add_job(args, opts \\ []) do
        Cue.add_job(@adapter, args, opts)
      end

      def add_jobs(args, opts \\ []) do
        Cue.add_jobs(@adapter, args, opts)
      end
    end
  end

  defmacro __using__(opts) do
    ast = quoted_adapter_ast(opts)

    quote do
      unquote(ast)
    end
  end
end
