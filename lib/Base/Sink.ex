defmodule Base.Sink do
  alias Membrane.Buffer

  @plot_path "plot.svg"
  @statistics_path "stats.csv"
  @available_statistics [:throughput, :generator_frequency, :passing_time_avg, :passing_time_std, :tick, :tries_counter]

  def handle_init(opts) do
    statistics = opts.statistics |> Enum.filter(fn key -> key in @available_statistics end)

    state = %{
      message_count: 0,
      start_time: 0,
      tick: opts.tick,
      how_many_tries: opts.how_many_tries,
      tries_counter: 0,
      sum: 0,
      squares_sum: 0,
      times: [],
      numerator_of_probing_factor: opts.numerator_of_probing_factor,
      denominator_of_probing_factor: opts.denominator_of_probing_factor,
      status: :playing,
      throughput: 0,
      should_produce_plots?: opts.should_produce_plots?,
      output_directory: opts.output_directory,
      supervisor_pid: opts.supervisor_pid,
      statistics: statistics,
      passing_time_avg: 0,
      passing_time_std: 0,
      generator_frequency: 0
    }

    if opts.provide_statistics_header? do
      provide_results_file_header(state)
    end

    {:ok, state}
  end

  def handle_write(:input, buffer, _context, state = %{status: :playing}) do
    state =
      if state.message_count == 0 do
        Process.send_after(self(), :tick, state.tick)
        %{state | start_time: Membrane.Time.monotonic_time()}
      else
        state
      end

    time = Membrane.Time.monotonic_time() - buffer.dts

    state =
      if :rand.uniform(state.denominator_of_probing_factor) <= state.numerator_of_probing_factor do
        Map.update!(state, :times, &[{buffer.dts - state.start_time, time} | &1])
      else
        state
      end

    state = Map.update!(state, :message_count, &(&1 + 1))
    state = Map.update!(state, :sum, &(&1 + time))
    state = Map.update!(state, :squares_sum, &(&1 + time * time))
    {{:ok, []}, state}
  end

  def handle_write(
        :input,
        %Buffer{payload: :flush, metadata: generator_frequency},
        _ctx,
        state = %{status: :flushing}
      ) do
    passing_time_avg = state.sum / state.message_count

    passing_time_std =
      :math.sqrt(
        (state.squares_sum + state.message_count * passing_time_avg * passing_time_avg - 2 * passing_time_avg * state.sum) /
          (state.message_count - 1)
      )

    state = %{state | passing_time_avg: passing_time_avg, passing_time_std: passing_time_std, generator_frequency: generator_frequency}

    write_demanded_statistics(state)

    specification =
      check_normality(
        state.times,
        passing_time_avg,
        passing_time_std,
        state.throughput,
        generator_frequency,
        state.tries_counter
      )

    actions =
      if state.tries_counter == state.how_many_tries do
        send(state.supervisor_pid, {:generator_frequency_found, generator_frequency})
        [notify: :stop]
      else
        [notify: {:play, specification}]
      end

    state = %{
      state
      | message_count: 0,
        sum: 0,
        squares_sum: 0,
        times: [],
        tries_counter: state.tries_counter + 1,
        status: :playing
    }

    {{:ok, actions}, state}
  end

  def handle_write(:input, _msg, _ctx, state = %{status: :flushing}) do
    {{:ok, []}, state}
  end

  def handle_other(:tick, _ctx, state) do
    elapsed = (Membrane.Time.monotonic_time() - state.start_time) / Membrane.Time.second()
    throughput = state.message_count / elapsed
    {actions, state} = {[notify: :flush], %{state | status: :flushing}}
    state = %{state | throughput: throughput}
    {{:ok, actions}, state}
  end

  defp check_normality(_times, passing_time_avg, passing_time_std, _throughput, generator_frequency, try_no) do
    cond do
      try_no == 0 ->
        :the_same

      passing_time_avg > 20_000_000 ->
        :slower

      passing_time_std > 10_000_000 and passing_time_std > 0.5 * passing_time_avg ->
        :slower

      true ->
        :faster
    end
  end

  defp write_demanded_statistics(state) do
    content = state.statistics |> Enum.map(fn key -> Map.get(state, key) end) |> Enum.join(",")
    content = content <> "\n"
    File.write(@statistics_path, content, [:append])

    if state.should_produce_plots? do
      output = Utils.prepare_plot(state.times, state.passing_time_avg, state.passing_time_std)
      File.write!(Integer.to_string(state.tries_counter) <> "_" <> @plot_path, output)
    end
  end

  defp provide_results_file_header(state) do
    content = (state.statistics |> Enum.join(",")) <> "\n"

    File.write(
      @statistics_path,
      content,
      [:append]
    )
  end
end
