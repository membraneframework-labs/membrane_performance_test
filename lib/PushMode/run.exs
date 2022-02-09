# {:ok, pid} = Supervisor.start_link(Membrane.Telemetry.TimescaleDB, [])

# :telemetry.attach("membrane-timescaledb-handler", [:membrane, :element, :init], fn a, b, c, d -> IO.inspect "#{a} #{b} #{c} #{d}" end, nil)

{:ok, pid} =
  Pipeline.start_link(%{
    n: 10,
    source: %PushMode.Elements.Source{initial_lower_bound: 0, initial_upper_bound: 100_000},
    filter: %PushMode.Elements.Filter{id: -1},
    sink: %PushMode.Elements.Sink{
      tick: 10_000,
      how_many_tries: 10,
      numerator_of_probing_factor: 1,
      denominator_of_probing_factor: 100,
      should_produce_plots?: true
    }
  })

Pipeline.play(pid)
Utils.wait_for_complete(pid)
