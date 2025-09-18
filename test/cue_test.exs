defmodule CueTest do
  use Cue.DataCase
  doctest Cue

  defmodule MockMaestro do
    use Cue,
      adapter: Cue.Adapters.Oban,
      director: {Cue.Adapters.Oban.Instance, name: :mock_instance},
      retry_policy: %{
        adapter: Cue.Adapters.Oban.Retry.Strategies.Linear,
        max_attempts: 20,
        min_attempts: 0
      }

    def perform(job) do
      {:ok, job}
    end
  end

  def start_oban_facade do
    pid =
      start_supervised!(
        {Cue.Adapters.Oban.Instance, repo: @repo, queues: [default: 10], testing: :inline}
      )

    %{pid: pid}
  end

  describe "config/0" do
    test "" do
      assert %Cue.Config{
               director: {Cue.Adapters.Oban.Instance, :mock_instance},
               retry_policy: %{
                 adapter: Cue.Adapters.Oban.Retry.Strategies.Linear,
                 max_attempts: 20,
                 min_attempts: 0
               }
             } = Cue.config(MockMaestro)
    end
  end

  describe "add_job/1" do
    test "" do
      assert {:ok, %Oban.Job{args: %{"name" => "job_name"}}} =
               Cue.add_job(MockMaestro, %{name: "job_name"})
    end
  end

  describe "add_jobs/1" do
    test "" do
      assert [
               %Oban.Job{args: %{"name" => "job_name_1"}},
               %Oban.Job{args: %{"name" => "job_name_2"}}
             ] =
               Cue.add_jobs(MockMaestro, [%{name: "job_name_1"}, %{name: "job_name_2"}])
    end
  end
end
