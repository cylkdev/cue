defmodule Cue.Adapters.Oban.CommonWorkerTest do
  use Cue.DataCase

  alias Cue.Adapters.Oban.CommonWorker

  @repo Cue.Repo

  defmodule MockInstance do
    def start_link(opts) do
      opts
      |> Keyword.put(:name, __MODULE__)
      |> Oban.start_link()
    end

    def child_spec(opts) do
      %{
        id: __MODULE__,
        start: {__MODULE__, :start_link, [opts]}
      }
    end

    def insert(changeset, opts) do
      Oban.insert(__MODULE__, changeset, opts)
    end

    def insert_all(changesets, opts) do
      Oban.insert_all(__MODULE__, changesets, opts)
    end
  end

  defmodule MockWorker do
    use Cue.Adapters.Oban.CommonWorker,
      instance: MockInstance,
      name: :mock_worker,
      retry_policy: %{
        adapter: Cue.Adapters.Oban.Retry.Strategy.Linear,
        max_attempts: 20,
        min_attempts: 0
      },
      on_requeue_error: :cancel

    def perform_job(%Oban.Job{} = job), do: {:ok, job}
  end

  def start_oban_facade do
    pid = start_supervised!({MockInstance, repo: @repo, queues: [default: 10], testing: :inline})
    %{pid: pid}
  end

  def start_oban_instance do
    name = :"oban_#{Enum.random(1..1_000_000)}"

    pid =
      start_supervised!({Oban, name: name, repo: @repo, queues: [default: 10], testing: :inline})

    %{name: name, pid: pid}
  end

  describe "config/1" do
    test "returns the config" do
      assert %CommonWorker.Config{
               instance: MockInstance,
               name: :mock_worker,
               retry_policy: %{
                 adapter: Cue.Adapters.Oban.Retry.Strategy.Linear,
                 max_attempts: 20,
                 min_attempts: 0
               },
               on_requeue_error: :cancel
             } = MockWorker.config()
    end
  end

  describe "enqueue_job/1" do
    test "can insert a job" do
      _oban = start_oban_facade()

      assert {:ok, %Oban.Job{args: %{"name" => "job_name"}}} =
               MockWorker.enqueue_job(%{name: "job_name"})
    end

    test "can insert a job given a struct" do
      _oban = start_oban_facade()

      assert {:ok, job} =
               MockWorker.enqueue_job(%{name: "job_name"})

      assert {:ok, %Oban.Job{args: %{"name" => "job_name"}}} =
               MockWorker.enqueue_job(job)
    end
  end

  describe "enqueue_jobs/1" do
    test "inserts multiple jobs" do
      _oban = start_oban_facade()

      assert [job1, job2] =
               MockWorker.enqueue_jobs([
                 %{name: "job_name_1"},
                 %{name: "job_name_2"}
               ])

      assert %Oban.Job{args: %{"name" => "job_name_1"}} = job1
      assert %Oban.Job{args: %{"name" => "job_name_2"}} = job2
    end

    test "inserts multiple jobs given structs" do
      _oban = start_oban_facade()

      assert [old_job1, old_job2] =
               MockWorker.enqueue_jobs([
                 %{name: "job_name_1"},
                 %{name: "job_name_2"}
               ])

      assert [new_job1, new_job2] =
               MockWorker.enqueue_jobs([old_job1, old_job2])

      assert %Oban.Job{args: %{"name" => "job_name_1"}} = new_job1
      assert %Oban.Job{args: %{"name" => "job_name_2"}} = new_job2
    end
  end
end
