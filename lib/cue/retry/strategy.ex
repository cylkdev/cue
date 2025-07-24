defmodule Cue.Retry.Strategy do
  @moduledoc """
  Defines the behavior required by retry strategy modules.

  A retry adapter is responsible for:

    * Classifying the result of a job execution as either retryable or terminal.
    * Returning a delay (in seconds) to wait before the next retry attempt.

  Strategy modules must implement this behaviour to be used with
  `Cue.Retry.Policy`.
  """

  @typedoc "The result of classifying a job execution."
  @type classification :: :ok | {:error, term()}

  @doc """
  Interprets the result of a job function.

  Returns `:ok` if the job was successful or should not be retried,
  or `{:error, reason}` if it should be retried.

  The result is passed directly from the job function’s return value.
  """
  @callback handle_classification(result :: term()) :: classification()

  @doc """
  Returns the number of seconds to wait before retrying a failed job.

  The delay may be constant, linear, exponential, or calculated in any
  way the adapter chooses. It must be a non-negative integer.
  """
  @callback handle_retry(job :: Oban.Job.t()) :: non_neg_integer()
end
