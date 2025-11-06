defmodule Cue.Application do
  use Application

  @name Cue.Supervisor

  def start(_type, _args) do
    children = children()

    opts = [strategy: :one_for_one, name: @name]
    Supervisor.start_link(children, opts)
  end

  def children do
    if Cue.Config.auto_start() do
      [{Cue, Cue.Config.schedulers()}]
    else
      []
    end
  end
end
