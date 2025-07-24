defmodule Cue.MixProject do
  use Mix.Project

  def project do
    [
      app: :cue,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Cue.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_options, ">= 0.0.0"},
      {:error_message, ">= 0.0.0", optional: true},
      {:jason, ">= 0.0.0", optional: true},
      {:oban, ">= 0.0.0", optional: true},
      {:ecto, ">= 0.0.0", optional: true},
      {:ecto_sql, ">= 0.0.0", optional: true},
      {:postgrex, ">= 0.0.0", optional: true}
    ]
  end
end
