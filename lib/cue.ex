defmodule Cue do
  @callback adapter :: module()
  @callback enqueue_job(any(), keyword()) :: {:ok, any()} | {:error, any()}
  @callback enqueue_jobs(any(), keyword()) :: {:ok, [any()]} | {:error, any()}

  def adapter(adapter), do: adapter.adapter()

  def enqueue_job(adapter, args, opts) do
    adapter.enqueue_job(args, opts)
  end

  def enqueue_jobs(adapter, args, opts) do
    adapter.enqueue_jobs(args, opts)
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

  def build_ast(opts) do
    quote do
      opts = unquote(opts)

      opts = Cue.validate_adapter_options!(opts)

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
    ast = build_ast(opts)

    quote do
      unquote(ast)
    end
  end
end
