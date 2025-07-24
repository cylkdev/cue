defmodule Cue.Adapters.Oban.Retry.Strategy.Exponential do
  @moduledoc """
  An exponential backoff retry strategy.

  This strategy applies exponential delay with jitter, capped to a maximum
  threshold. It follows the formula:

      delay = min((2^attempt * base) + jitter, cap)

  ## Backoff parameters

    * `base` — the base multiplier used for exponential growth (default: `15`)
    * `jitter` — random additional delay between 0 and this value (default: `30`)
    * `cap` — maximum allowed delay in seconds (default: `86_400`, i.e. 24 hours)

  These parameters are fixed in the current implementation, but this strategy
  may be extended to accept runtime configuration in the future.
  """

  @behaviour Cue.Retry.Strategy

  @default_base 15
  @default_jitter 30
  @default_cap :timer.hours(24)

  @doc """
  Interprets the result of a job function.

  Accepts standard return shapes and classifies them as either successful
  (`:ok`) or retryable (`{:error, reason}`).

  Any unrecognized value is returned as an invalid error tuple.
  """
  @impl true
  @spec handle_classification(term()) :: :ok | {:error, term()}
  def handle_classification(:ok), do: :ok
  def handle_classification({:ok, _}), do: :ok
  def handle_classification({:error, reason}), do: {:error, reason}
  def handle_classification(other), do: {:error, {:invalid_response, other}}

  @doc """
  Returns the number of seconds to delay before retrying a job.

  Uses exponential growth with jitter, capped at 24 hours by default.
  """
  @impl true
  @spec handle_retry(Oban.Job.t()) :: non_neg_integer()
  def handle_retry(%Oban.Job{attempt: attempt}) do
    base_delay = :math.pow(2, attempt) * @default_base
    jitter = :rand.uniform(@default_jitter)
    delay = trunc(base_delay + jitter)

    min(delay, @default_cap)
  end
end
