{:ok, pid} = PullMode.Pipeline.start_link(%{n: 25, tick: 20_000, how_many_tries: 3})
PullMode.Pipeline.play(pid)
Utils.wait_for_complete(pid)
