defmodule Cue.Adapter do
  @callback add_job(params :: term(), opts :: keyword()) :: {:ok, any()} | {:error, any()}
  @callback add_jobs(params_list :: list(), opts :: keyword()) :: list(any()) | any()
  @callback schedule_job(
              worker_or_job :: term(),
              params :: term(),
              delay :: term(),
              opts :: keyword()
            ) ::
              {:ok, any()} | {:error, any()}

  def add_job(adapter, params, opts), do: adapter.add_job(params, opts)

  def add_jobs(adapter, params_list, opts), do: adapter.add_jobs(params_list, opts)

  def schedule_job(adapter, worker_or_job, params, delay_sec_or_datetime, opts) do
    adapter.schedule_job(worker_or_job, params, delay_sec_or_datetime, opts)
  end
end
