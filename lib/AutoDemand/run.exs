{:ok, pid} =
  Pipeline.start_link(%{
    n: 10,
    filter: %AutoDemand.Elements.Filter{id: -1},
    source: AutoDemand.Elements.Source,
    sink: %AutoDemand.Elements.Sink{tick: 100_00, how_many_tries: 10}
  })

Pipeline.play(pid)
Utils.wait_for_complete(pid)
