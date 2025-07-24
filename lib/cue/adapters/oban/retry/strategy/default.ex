defmodule Cue.Adapters.Oban.Retry.Strategy.Default do
  @moduledoc """
  The default retry strategy used by `Cue.Retry.Policy`.

  This strategy applies a cubic backoff with jitter and handles common
  result shapes returned by Oban job execution.

  Backoff formula:

      backoff = attempt^3 + 15 + jitter

  Where jitter is a random number between 0 and 30 seconds.
  """

  @behaviour Cue.Retry.Strategy

  @doc """
  Interprets the result of a job function.

  Recognizes the following return values:

    * `:ok` — considered successful
    * `{:ok, _}` — considered successful
    * `{:error, reason}` — considered retryable
    * any other value — classified as invalid

  Returns `:ok` or `{:error, reason}`.
  """
  @impl true
  @spec handle_classification(term()) :: :ok | {:error, term()}
  def handle_classification(:ok), do: :ok
  def handle_classification({:ok, _}), do: :ok
  def handle_classification({:error, reason}), do: {:error, reason}
  def handle_classification(other), do: {:error, {:invalid_response, other}}

  @doc """
  Returns the number of seconds to delay before retrying the job.

  Uses a cubic backoff strategy with jitter:

      trunc(:math.pow(attempt, 3) + 15) + rand(1..30)
  """
  @impl true
  @spec handle_retry(Oban.Job.t()) :: non_neg_integer()
  def handle_retry(%Oban.Job{attempt: attempt}) do
    base = trunc(:math.pow(attempt, 3) + 15)
    base + :rand.uniform(30)
  end
end
