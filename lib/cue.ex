defmodule Cue do
  @moduledoc ~S"""
  `Cue`

  # Installation

  Open your mix.exs and add the following to the deps/0 function:

      {:cue, "~> 0.1"}

  # Usage

  Before we jump into workers and jobs, let’s get the foundations in place.

  ## Step 1: Start your Repo

  Most examples assume you already have a Repo configured.
  For our walkthrough, let’s start the bundled support repo:

      Cue.Support.Repo.start_link()

  This makes sure we have a database connection ready for Oban.

  ## Step 2: Define a Worker

  Workers are where the “real work” happens. Let’s create a
  simple one that prints greetings:

      defmodule Greeter do
        use Cue.Act,
          actor: Cue.Oban.Performer,
          director: Cue.Oban,
          oban: [name: Greeter.Oban],
          params: %{event: "greeting"},
          max_attempts: 3,
          options: []

        @impl true
        def handle_perform(
          %Oban.Job{
            args: %{
              "event" => "greeting",
              "name" => name,
              "message" => message
            }
          },
          _config
        ) do
          IO.puts("#{message}, #{name}.")
          :ok
        end
      end

  Let’s unpack this a bit:

    - `use Cue.Act`: Brings in the necessary glue so your
      worker is recognized by Cue and integrated with Oban
      This sets up the scheduling and execution behaviour
      automatically.

    - `params`: A field specific to `Cue.Oban.Performer`. It
      defines default parameters that are merged into every
      worker call (e.g. `add_job/2` or `add_jobs/2`). This is
      useful when you want each job to always carry a certain
      key (for example, "event" => "greeting") without having
      to pass it every time.

    - `max_attempts: 3`: An option from `Oban.Worker`. Cue
      forwards any options it doesn’t use directly to the
      underlying adapter, so standard Oban options like
      `:max_attempts`, `:queue`, or `:priority` work as
      expected.

    - `handle_perform/2`: The required callback for all workers
      using `Cue.Oban.Performer`. It receives the `%Oban.Job{}`
      struct and your worker’s config. This is where you
      implement the actual logic-what the job does when it runs.

  ## Step 3: Start Oban

  In our worker definition we passed `oban: [name: Greeter.Oban]`.
  That means we need to start an Oban instance with the same name:

      Cue.Oban.start_link(name: Greeter.Oban)

  At this point:

    - The Repo is running.
    - The Oban instance is running.
    - Our worker module is defined.

  We’re ready to enqueue a job!

  ## Step 4: Add a Job

  Now let’s queue up a greeting for our worker:

      Greeter.add_job(%{"message" => "Hello", "name" => "John"})

  Once this job is picked up, Oban will pass the args into `handle_perform/2`, and you’ll see:

      Hello, John.

  ## Step 5: Starting Everything Together

  Manually starting the repo, Oban, and workers works fine-but
  for convenience you can start your **director and actor
  together** in one call:

      Cue.start_link(stage: [{Greeter, [oban: [name: Greeter.Oban]]}])

  This ensures all the moving parts-repo, Oban instance, director,
  and workers-boot up in the right order with a single call.

  From here, you can experiment by adding more workers, tweaking
  retry strategies, and composing more complex job orchestration.
  """

  alias Cue.Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(opts)
  end

  def child_spec(opts \\ []) do
    Supervisor.child_spec(opts)
  end
end
