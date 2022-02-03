
#{:ok, pid} = Supervisor.start_link(Membrane.Telemetry.TimescaleDB, [])

#:telemetry.attach("membrane-timescaledb-handler", [:membrane, :element, :init], fn a, b, c, d -> IO.inspect "#{a} #{b} #{c} #{d}" end, nil)

{:ok, pid} = Pipeline.start_link(%{n: 4,
  filter: %PushMode.Elements.Filter{id: -1},
  source: PushMode.Elements.Source,
  sink: %PushMode.Elements.Sink{tick: 10_000, how_many_tries: 3, a: 1, b: 10}
})
Pipeline.play(pid)
Utils.wait_for_complete(pid)
