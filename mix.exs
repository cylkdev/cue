defmodule Cue.MixProject do
  use Mix.Project

  def project do
    [
      app: :cue,
      version: "0.1.0",
      elixir: "~> 1.18",
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

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_options, ">= 0.1.0"},
      {:error_message, ">= 0.1.0", optional: true},
      {:oban, ">= 0.1.0", optional: true}
    ]
  end
end
