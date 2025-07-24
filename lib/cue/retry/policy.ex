defmodule Cue.Retry.Policy do
  @moduledoc """
  Defines a retry policy for job execution.

  A policy describes how job results should be interpreted, when a job is
  eligible for retry, and what retry strategy should be used. Policies are
  evaluated by `Cue.Retry.perform/3`.

  Retry behavior is delegated to a strategy adapter that implements the
  `Cue.Retry.Adapter` behaviour.

  ## Fields

    * `:adapter` — the module that implements retry classification and delay logic.
    * `:max_attempts` — the maximum number of retry attempts (inclusive).
    * `:min_attempts` — the minimum number of attempts before retry logic is applied.
  """

  @type t :: %__MODULE__{
          adapter: module(),
          max_attempts: pos_integer(),
          min_attempts: non_neg_integer()
        }

  @default_options [
    max_attempts: 20,
    min_attempts: 0
  ]

  @definition [
    adapter: [
      required: true,
      type: :module,
      doc: "The retry strategy module"
    ],
    max_attempts: [
      required: true,
      type: :integer,
      doc: "Maximum number of attempts (inclusive)"
    ],
    min_attempts: [
      required: true,
      type: :integer,
      doc: "Minimum attempts required to trigger retry"
    ]
  ]

  defstruct [:adapter, :max_attempts, :min_attempts]

  @doc """
  Builds a new retry policy from the given options.

  This function merges defaults with the given keyword list and ensures
  a valid adapter is provided.

  ## Options

    * `:adapter` — the retry strategy module
    * `:max_attempts` — maximum number of attempts (default: `20`)
    * `:min_attempts` — minimum attempts required to trigger retry (default: `0`)

  ## Examples

      iex> Policy.new(adapter: MyApp.CustomStrategy, max_attempts: 5)
      %Policy{adapter: MyApp.CustomStrategy, max_attempts: 5, min_attempts: 0}
  """
  @spec new(Keyword.t()) :: t()
  def new(opts \\ []) do
    opts
    |> Keyword.merge(@default_options)
    |> NimbleOptions.validate!(@definition)
    |> then(&struct!(__MODULE__, &1))
  end
end
