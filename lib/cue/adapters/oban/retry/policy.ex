defmodule Cue.Adapters.Oban.Retry.Policy do
  alias Cue.Retry.Policy

  @doc """
  Returns a retry policy using the `Cue.Adapters.Oban.Retry.Strategy.Exponential` adapter.

  Accepts the same options as `new/1`.
  """
  def exponential(opts \\ []) do
    opts
    |> Keyword.put(:adapter, Cue.Adapters.Oban.Retry.Strategy.Exponential)
    |> Policy.new()
  end

  @doc """
  Returns a retry policy using the `Cue.Adapters.Oban.Retry.Strategy.Linear` adapter.

  Accepts the same options as `new/1`.
  """
  def linear(opts \\ []) do
    opts
    |> Keyword.put(:adapter, Cue.Adapters.Oban.Retry.Strategy.Linear)
    |> Policy.new()
  end

  @doc """
  Returns a retry policy using the default strategy adapter.

  This is equivalent to calling `new/1` with no adapter override.
  """
  def default(opts \\ []) do
    opts
    |> Keyword.put(:adapter, Cue.Adapters.Oban.Retry.Strategy.Default)
    |> Policy.new()
  end
end
