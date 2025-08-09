defmodule Cue.Adapters.Oban.CommonWorker do
  alias Cue.Adapters.Oban.Core
  alias Cue.Adapters.Oban.Retry

  @callback config() :: Cue.Adapters.Oban.CommonWorker.Config.t()
  @callback perform_job(module(), Oban.Job.t()) ::
              {:ok, Oban.Job.t()} | {:error, term()}
  @callback enqueue_job(any()) :: {:ok, Oban.Job.t()} | {:error, term()}
  @callback enqueue_jobs(list(any())) :: list(Oban.Job.t()) | Ecto.Multi.t()

  def config(worker), do: worker.config()

  def perform_job(worker, job) do
    config = config(worker)

    case config.retry_policy do
      nil ->
        job
        |> worker.perform_job()
        |> handle_perform_response(worker, job, config)

      policy ->
        policy =
          case policy do
            %Cue.Retry.Policy{} -> policy
            params when is_map(params) -> params |> Map.to_list() |> Cue.Retry.Policy.new()
            params -> Cue.Retry.Policy.new(params)
          end

        job
        |> Retry.perform(
          fn job ->
            worker.perform_job(job)
          end,
          policy
        )
        |> handle_perform_response(worker, job, config)
    end
  end

  defp handle_perform_response({:snooze, delay}, worker, job, config) do
    handle_perform_response({:snooze, delay, nil}, worker, job, config)
  end

  defp handle_perform_response({:snooze, delay, reason}, worker, job, config) do
    oban_opts =
      worker
      |> build_oban_opts()
      |> put_schedule(delay)

    case Core.insert(job, oban_opts) do
      {:ok, new_job} ->
        if reason do
          {:ok, %{job: new_job, reason: reason}}
        else
          {:ok, %{job: new_job}}
        end

      {:error, error_reason} ->
        case config.on_error || :nothing do
          :cancel -> {:cancel, error_reason}
          :nothing -> {:error, error_reason}
        end
    end
  end

  defp handle_perform_response({:cancel, reason}, _worker, _job, _config) do
    {:cancel, %{reason: reason}}
  end

  defp handle_perform_response({:cancel, :max_attempts_exceeded, reason}, _worker, _job, _config) do
    {:cancel, %{code: :max_attempts_exceeded, reason: reason}}
  end

  defp handle_perform_response(:ok, _worker, _job, _config) do
    :ok
  end

  defp handle_perform_response({:ok, _} = success, _worker, _job, _config) do
    success
  end

  defp handle_perform_response({:error, _} = error, _worker, _job, _config) do
    error
  end

  defp handle_perform_response(response, worker, _job, _config) do
    raise RuntimeError, "Invalid response from worker #{inspect(worker)}: #{inspect(response)}"
  end

  @doc """
  Inserts a job using the configuration associated with the given worker.

  This merges static options from the worker with any provided at runtime.
  """
  @spec enqueue_job(module(), any()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue_job(worker, params_or_changeset) do
    Core.insert(params_or_changeset, build_oban_opts(worker))
  end

  @doc """
  Inserts multiple jobs using the configuration associated with the given worker.

  This merges static options from the worker with any provided at runtime.
  """
  @spec enqueue_jobs(module(), list(any())) :: list(Oban.Job.t()) | Ecto.Multi.t()
  def enqueue_jobs(worker, params_or_changesets) do
    Core.insert_all(params_or_changesets, build_oban_opts(worker))
  end

  defp build_oban_opts(worker) do
    config = config(worker)

    cond do
      not is_nil(config.instance) ->
        [worker: worker, instance: config.instance]

      not is_nil(config.name) ->
        [worker: worker, name: config.name]

      true ->
        [worker: worker]
    end
  end

  defp put_schedule(opts, delay) do
    cond do
      is_struct(delay, DateTime) -> Keyword.put(opts, :scheduled_at, delay)
      is_integer(delay) -> Keyword.put(opts, :schedule_in, delay)
      true -> opts
    end
  end

  defmacro __using__(opts) do
    worker_opts =
      Keyword.take(opts, [
        :max_attempts,
        :priority,
        :queue,
        :tags,
        :replace,
        :unique
      ])

    other_opts =
      Keyword.drop(opts, [
        :max_attempts,
        :priority,
        :queue,
        :tags,
        :replace,
        :unique
      ])

    quote do
      opts = unquote(other_opts)

      use Oban.Worker, unquote(worker_opts)

      alias Cue.Adapters.Oban.CommonWorker

      @behaviour Cue.Adapters.Oban.CommonWorker

      @config %CommonWorker.Config{
        instance: opts[:instance],
        name: opts[:name],
        retry_policy: opts[:retry_policy],
        on_error: opts[:on_error]
      }

      @doc false
      @impl true
      def config, do: @config

      @impl true
      def perform(job) do
        CommonWorker.perform_job(__MODULE__, job)
      end

      @impl true
      def enqueue_job(params_or_changeset) do
        CommonWorker.enqueue_job(__MODULE__, params_or_changeset)
      end

      @impl true
      def enqueue_jobs(params_or_changesets) do
        CommonWorker.enqueue_jobs(__MODULE__, params_or_changesets)
      end
    end
  end
end
