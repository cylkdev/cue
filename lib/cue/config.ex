defmodule Cue.Config do
  @app :cue

  @spec error_module() :: module()
  def error_module do
    Application.get_env(@app, :error_module) || ErrorMessage
  end
end
