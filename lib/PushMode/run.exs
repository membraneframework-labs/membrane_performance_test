{:ok, pid} = PushMode.Pipeline.start_link(%{n: 25, tick: 20_000})
PushMode.Pipeline.play(pid)
Utils.wait_for_complete(pid)
