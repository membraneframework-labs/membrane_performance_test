{:ok, pid} = Pipeline.start_link(%{n: 30,
  filter: %PullMode.Elements.Filter{id: -1},
  source: PullMode.Elements.Source,
  sink: %PullMode.Elements.Sink{tick: 100_000, how_many_tries: 3}
})
Pipeline.play(pid)
Utils.wait_for_complete(pid)
