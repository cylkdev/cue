import Config

config :cue, ecto_repos: [Cue.Repo]

if Mix.env() === :test do
  config :cue, Cue.Repo,
    database: "cue_test",
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10,
    show_sensitive_data_on_connection_error: true,
    stacktrace: true
end
