defmodule Cue.Adapters.Oban.CommonWorker do
  @moduledoc """
  Provides a standardized interface for Oban workers across umbrella applications.

  This module ensures each worker can:

    * Re-insert or requeue jobs without needing to know the Oban configuration
    * Automatically merge static options (like instance name) with runtime options
    * Maintain predictable and reusable insertion logic

  ## Usage

      defmodule MyApp.Workers.FooWorker do
        use Cue.CommonWorker,
          name: :my_app_oban,
          instance: MyApp.Oban

        @impl Oban.Worker
        def perform(%Oban.Job{args: %{"id" => id}}, _job) do
          # ...
        end
      end

      # Then from anywhere:
      MyApp.Workers.FooWorker.insert(%{"id" => 123})
  """

  alias Cue.Adapters.Oban.API

  @type insert_result :: {:ok, Oban.Job.t()} | {:error, term()} | Ecto.Multi.t()
  @type insert_all_result :: list(Oban.Job.t()) | Ecto.Multi.t()

  @callback requeue(Oban.Job.t(), keyword()) :: insert_result()
  @callback insert(any(), keyword()) :: insert_result()
  @callback insert_all(list(any()), keyword()) :: insert_all_result()

  @doc """
  Retrieves the static Oban configuration associated with a given worker module.
  """
  @spec instance_options(module()) :: keyword()
  def instance_options(worker), do: worker.instance_options()

  @doc """
  Re-inserts a job using its current arguments and the configuration from the caller worker.

  This is useful for re-enqueuing the same job manually (e.g. on transient failure).
  """
  @spec requeue(module(), Oban.Job.t(), keyword()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def requeue(worker, %Oban.Job{args: args} = _job, opts \\ []) do
    insert(worker, args, opts)
  end

  @doc """
  Inserts a job using the configuration associated with the given worker.

  This merges static options from the worker with any provided at runtime.
  """
  @spec insert(module(), any(), keyword()) :: insert_result()
  def insert(worker, params_or_changeset, opts \\ []) do
    opts = with_oban_opts(opts, worker)

    API.insert(params_or_changeset, opts)
  end

  @doc """
  Inserts multiple jobs using the configuration associated with the given worker.

  This merges static options from the worker with any provided at runtime.
  """
  @spec insert_all(module(), list(any()), keyword()) :: insert_all_result()
  def insert_all(worker, params_or_changesets, opts \\ []) do
    opts = with_oban_opts(opts, worker)

    API.insert_all(params_or_changesets, opts)
  end

  defp with_oban_opts(opts, worker) do
    instance_options = instance_options(worker)

    opts
    |> Keyword.put(:worker, worker)
    |> put_new_when_not_nil(:instance, instance_options[:instance])
    |> put_new_when_not_nil(:name, instance_options[:name])
  end

  defp put_new_when_not_nil(opts, _key, nil) do
    opts
  end

  defp put_new_when_not_nil(opts, key, value) do
    Keyword.put_new(opts, key, value)
  end

  @adapter_definition [
    # API-specific options
    instance: [
      type: :atom,
      doc: "The module that implements the Oban instance, used to insert or schedule the job."
    ],
    name: [
      type: :atom,
      doc:
        "The registered name of the Oban process, typically used to address a specific instance."
    ],

    # Oban.Job.new/2 options
    queue: [
      type: :atom,
      default: :default,
      doc: "The name of the queue the job will be pushed to."
    ],
    tags: [
      type: {:list, :binary},
      default: [],
      doc: "A list of binary tags for categorizing or filtering jobs."
    ],
    meta: [
      type: :map,
      default: %{},
      doc: "A map of additional metadata stored with the job for reference."
    ],
    priority: [
      type: :non_neg_integer,
      default: 0,
      doc: "An integer from 0 (highest) to 9 (lowest) controlling the job's priority."
    ],
    max_attempts: [
      type: :pos_integer,
      default: 20,
      doc: "The maximum number of times a job may be retried on failure."
    ],
    schedule_in: [
      type: :integer,
      doc: "Number of seconds in the future when the job should be scheduled."
    ],
    scheduled_at: [
      type: :naive_datetime,
      doc: "A specific `NaiveDateTime` when the job should become available for execution."
    ],
    replace: [
      type: {:list, :atom},
      doc: "A list of unique fields used to replace an existing job with the same values."
    ],
    unique: [
      type: :keyword_list,
      doc: """
      Options used to configure unique constraints for deduplication. See `Oban.Job.new/2` docs
      for full details on available keys such as `:keys`, `:period`, `:states`, etc.
      """
    ]
  ]

  @doc """
  Returns the NimbleOptions schema used for validating worker options.
  """
  def adapter_definition, do: @adapter_definition

  @doc """
  Validates the given keyword list against the worker option schema.

  Raises a `NimbleOptions.ValidationError` if any options are invalid.
  """
  @spec validate_adapter_options!(keyword()) :: keyword()
  def validate_adapter_options!(opts) do
    NimbleOptions.validate!(opts, @adapter_definition)
  end

  def quoted_adapter_ast(opts) do
    quote do
      opts = unquote(opts)

      opts = Cue.Adapters.Oban.CommonWorker.validate_adapter_options!(opts)

      oban_worker_options = Keyword.drop(opts, [:instance, :name])

      instance_options = Keyword.take(opts, [:instance, :name])

      alias Cue.Adapters.Oban.CommonWorker

      use Oban.Worker, oban_worker_options

      @behaviour Cue.Adapters.Oban.CommonWorker

      @instance_options instance_options

      @doc false
      def instance_options, do: @instance_options

      @impl true
      def requeue(job, opts \\ []) do
        CommonWorker.requeue(__MODULE__, job, opts)
      end

      @impl true
      def insert(params_or_changeset, opts \\ []) do
        CommonWorker.insert(__MODULE__, params_or_changeset, opts)
      end

      @impl true
      def insert_all(params_or_changesets, opts \\ []) do
        CommonWorker.insert_all(__MODULE__, params_or_changesets, opts)
      end
    end
  end

  @doc """
  Injects convenience functions into an Oban worker module for
  integration with the `Cue` API.

  This macro simplifies worker setup by centralizing instance
  configuration and defining standard job insertion functions.
  It allows workers to be self-contained meaning they are
  capable of scheduling and re-enqueuing jobs without
  requiring the caller to know about instance-level
  details, such as the Oban process name.

  ## Examples

  To define a worker with an associated Oban instance:

      defmodule MyApp.Workers.EmailWorker do
        use Cue.CommonWorker, instance: MyApp.ObanAPI

        @impl Oban.Worker
        def perform(%Oban.Job{args: %{"email" => email}}) do
          MyApp.Mailer.deliver(email)
        end
      end

  Once defined, the worker supports direct job insertion:

      EmailWorker.insert(%{"email" => "user@example.com"})

  To insert multiple jobs:

      EmailWorker.insert_all([
        %{"email" => "a@example.com"},
        %{"email" => "b@example.com"}
      ])

  ## Requeuing

  Jobs may also re-enqueue themselves using the same args and configuration:

      def perform(%Oban.Job{args: args} = job) do
        case do_work(args) do
          :ok -> :ok
          {:error, :retry} -> requeue(job)
        end
      end

  ## Options

  The macro accepts the following options:

    * `:instance` – the Oban instance module that this worker will use for insertion

  """
  defmacro __using__(opts) do
    ast = Cue.Adapters.Oban.CommonWorker.quoted_adapter_ast(opts)

    quote do
      unquote(ast)
    end
  end
end
