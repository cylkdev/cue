ExUnit.start()

{:ok, _} = Application.ensure_all_started([:postgrex, :ecto])
{:ok, _} = Cue.Repo.start_link()
