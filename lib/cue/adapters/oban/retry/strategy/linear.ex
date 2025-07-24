defmodule Cue.Adapters.Oban.Retry.Strategy.Linear do
  @moduledoc """
  A linear backoff retry strategy.

  This strategy applies a constant step interval between each retry attempt.
  The delay is calculated as:

      delay = attempt * step

  ## Parameters

    * `step` — the delay in seconds between each attempt (default: `30`)

  This implementation uses a fixed step size, but future versions may allow
  runtime configuration.
  """

  @behaviour Cue.Retry.Strategy

  @step_seconds 30

  @doc """
  Interprets the result of a job function.

  Recognizes standard result shapes (`:ok`, `{:ok, _}`, `{:error, _}`) and
  classifies them accordingly.

  Unrecognized values are marked as invalid.
  """
  @impl true
  @spec handle_classification(term()) :: :ok | {:error, term()}
  def handle_classification(:ok), do: :ok
  def handle_classification({:ok, _}), do: :ok
  def handle_classification({:error, reason}), do: {:error, reason}
  def handle_classification(other), do: {:error, {:invalid_response, other}}

  @doc """
  Returns the number of seconds to delay before retrying the job.

  Delay increases linearly by a fixed step with each retry attempt.
  """
  @impl true
  @spec handle_retry(Oban.Job.t()) :: non_neg_integer()
  def handle_retry(%Oban.Job{attempt: attempt}) do
    attempt * @step_seconds
  end
end
