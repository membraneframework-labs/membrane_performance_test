{:ok, pid} = PullMode.Pipeline.start_link(%{n: 25, tick: 20_000})
PullMode.Pipeline.play(pid)
Utils.wait_for_complete(pid)
