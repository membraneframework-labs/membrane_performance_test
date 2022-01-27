{:ok, pid} = PushMode.Pipeline.start_link(%{n: 3, tick: 100_000, how_many_tries: 3})
PushMode.Pipeline.play(pid)
Utils.wait_for_complete(pid)
