defmodule Cue.Adapter do
  @moduledoc """
  Documentation for `Cue.Adapter`.
  """

  @type adapter :: module()
  @type args :: any()
  @type options :: keyword()

  @callback enqueue_job(args(), options()) :: {:ok, any()} | {:error, any()}
  @callback enqueue_jobs(args(), options()) :: list(any()) | any()
end
