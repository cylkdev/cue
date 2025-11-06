defmodule Cue.Config do
  @moduledoc false
  @app :cue

  def get_env(key, default \\ nil), do: Application.get_env(@app, key) || default
  def auto_start, do: Application.get_env(@app, :auto_start, false)
  def schedulers, do: Application.get_env(@app, :schedulers) || []
end
