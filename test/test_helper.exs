ExUnit.start()

{:ok, _} = Application.ensure_all_started([:postgrex, :ecto])
{:ok, _} = Cue.Support.Repo.start_link()
