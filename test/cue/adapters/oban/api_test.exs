defmodule Cue.Adapters.Oban.APITest do
  use Cue.DataCase

  alias Cue.Adapters.Oban.API

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
    use Oban.Worker, queue: :default

    def perform(_job), do: :ok
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

  describe "insert/2" do
    test "inserts a job using name" do
      oban_instance = start_oban_instance()

      assert {:ok, job} =
               API.insert(%{name: "job_name"}, worker: MockWorker, name: oban_instance.name)

      assert %Oban.Job{args: %{"name" => "job_name"}} = job
    end

    test "inserts a job using instance module" do
      start_oban_facade()

      assert {:ok, job} =
               API.insert(%{name: "job_name"}, worker: MockWorker, instance: MockInstance)

      assert %Oban.Job{args: %{"name" => "job_name"}} = job
    end
  end

  describe "insert_all/2" do
    test "inserts multiple jobs using name" do
      oban_instance = start_oban_instance()

      assert [job1, job2] =
               API.insert_all(
                 [%{name: "job_name_1"}, %{name: "job_name_2"}],
                 worker: MockWorker,
                 name: oban_instance.name
               )

      assert %Oban.Job{args: %{"name" => "job_name_1"}} = job1
      assert %Oban.Job{args: %{"name" => "job_name_2"}} = job2
    end

    test "inserts multiple jobs using instance module" do
      start_oban_facade()

      assert [job1, job2] =
               API.insert_all(
                 [%{name: "job_name_1"}, %{name: "job_name_2"}],
                 worker: MockWorker,
                 instance: MockInstance
               )

      assert %Oban.Job{args: %{"name" => "job_name_1"}} = job1
      assert %Oban.Job{args: %{"name" => "job_name_2"}} = job2
    end
  end
end
