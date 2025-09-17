defmodule Cue.Supervisor do
  use Supervisor

  @supervisor_options_keys [:name, :strategy, :max_restarts, :max_seconds]
  @default_name __MODULE__
  @default_options [name: @default_name]

  def start_link(opts \\ []) do
    opts = Keyword.merge(@default_options, opts)

    Supervisor.start_link(
      __MODULE__,
      opts[:stage] || [],
      Keyword.take(opts, @supervisor_options_keys)
    )
  end

  def child_spec(opts \\ []) do
    opts = Keyword.merge(@default_options, opts)

    %{
      id: {__MODULE__, opts[:id] || opts[:name] || opts[:key] || :default},
      start: {__MODULE__, :start_link, [opts]},
      restart: Keyword.get(opts, :restart, :permanent),
      shutdown: Keyword.get(opts, :shutdown, 5_000),
      type: :worker
    }
  end

  @impl true
  def init(stage) do
    children = collect_child_specs(stage)
    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc false
  def collect_child_specs(children) do
    children
    |> Enum.map(fn
      {module, opts} -> {module, opts}
      module -> {module, []}
    end)
    |> Enum.map(fn {module, opts} ->
      director_spec =
        if ensure_function_exported?(module, :director, 0) do
          director = module.director()

          if ensure_function_exported?(director, :supervisor_child_spec, 1) do
            director.supervisor_child_spec(opts)
          end
        end

      child_spec =
        if ensure_function_exported?(module, :supervisor_child_spec, 1) do
          module.supervisor_child_spec(opts)
        end

      [director_spec, child_spec]
    end)
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> dedup()
  end

  defp dedup(children) do
    children
    |> Enum.reduce(MapSet.new(), fn entry, set -> MapSet.put(set, entry) end)
    |> MapSet.to_list()
  end

  defp ensure_function_exported?(module, func, arity) do
    Code.ensure_loaded?(module) and function_exported?(module, func, arity)
  end
end
