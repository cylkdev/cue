defmodule Cue.Config do
  @moduledoc false
  @app :cue

  def get_app_env(key, default), do: Application.get_env(@app, key) || default
  def adapters, do: Application.get_env(@app, :adapters) || []
end
