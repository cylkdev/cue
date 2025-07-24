defmodule Cue.Adapter do
  @moduledoc """
  Documentation for `Cue.Adapter`.
  """

  @type adapter :: module()
  @type args :: any()
  @type options :: keyword()

  @callback add_job(args(), options()) :: {:ok, any()} | {:error, any()}
  @callback add_jobs(args(), options()) :: {:ok, [any()]} | {:error, any()}
end
