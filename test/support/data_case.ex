defmodule Cue.Support.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Cue.Support.Repo

      use Oban.Testing, repo: Cue.Support.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Cue.Support.DataCase
    end
  end

  setup tags do
    setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Cue.Support.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Cue.Support.Repo, {:shared, self()})
    end
  end

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        atom_key = String.to_existing_atom(key)
        opts |> Keyword.get(atom_key, key) |> to_string()
      end)
    end)
  end
end
