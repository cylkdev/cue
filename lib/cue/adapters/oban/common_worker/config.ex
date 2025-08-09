defmodule Cue.Adapters.Oban.CommonWorker.Config do
  @type t :: %__MODULE__{
          instance: String.t() | nil,
          name: String.t() | nil,
          retry_policy: Cue.Retry.Policy.t() | nil,
          on_requeue_error: :raise | :cancel | :nothing
        }

  defstruct [:instance, :name, :retry_policy, :on_requeue_error]
end
