defmodule Cue.Adapters.Oban.Retry do
  @behaviour Cue.Retry

  @impl true
  @doc """
  Executes a job function and applies retry behavior based on the given policy.

  ## Return values

    * `:ok` — the job was successful and does not require retry.
    * `{:snooze, delay, reason}` — the job will be retried after `delay` seconds.
    * `{:cancel, reason}` — the job should be canceled and not retried again.

  ## Examples

      policy = Cue.Retry.Policy.exponential(max_attempts: 5)

      Cue.Retry.perform(job, fn job -> MyWorker.perform(job) end, policy)
  """
  def perform(%Oban.Job{} = job, fun, %Cue.Retry.Policy{} = policy) do
    result = classify(policy, fun.(job))

    if retry?(result, job, policy) do
      {:snooze, backoff(policy, job), extract_reason(result)}
    else
      {:cancel, :max_attempts_exceeded, result}
    end
  end

  defp classify(%Cue.Retry.Policy{adapter: adapter}, result),
    do: adapter.handle_classification(result)

  defp backoff(%Cue.Retry.Policy{adapter: adapter}, job),
    do: adapter.handle_retry(job)

  defp retry?({:error, _}, %Oban.Job{attempt: attempt}, %Cue.Retry.Policy{
         min_attempts: min,
         max_attempts: max
       }) do
    attempt >= min and attempt < max
  end

  defp retry?(:ok, _, _), do: false

  defp extract_reason({:error, reason}), do: reason
  defp extract_reason(_), do: nil
end
