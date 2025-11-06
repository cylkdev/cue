import Config

config :cue,
  auto_start: false,
  schedulers: []

config :cue, Oban,
  name: Cue.Adapters.Oban,
  repo: Cue.Repo,
  queues: [default: 10]

config :cue, :ecto_repos, [Cue.Repo]

if Mix.env() === :test do
  config :cue, :sql_sandbox, true

  config :cue, Cue.Repo,
    username: "postgres",
    database: "cue_test",
    password: "password",
    hostname: "localhost",
    show_sensitive_data_on_connection_error: true,
    log: :debug,
    stacktrace: true,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10
else
  config :cue, Cue.Repo,
    username: "postgres",
    database: "cue",
    password: "password",
    hostname: "localhost",
    show_sensitive_data_on_connection_error: true,
    log: :debug,
    pool_size: 10
end
