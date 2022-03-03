defmodule Base.Sink do
  alias Membrane.Buffer

  @available_metrics [
    :throughput,
    :generator_frequency,
    :passing_time_avg,
    :passing_time_std,
    #:tick,
    #:tries_counter
  ]
  @plot_filename "plot.svg"

  defmacro __using__(_opts) do
    quote do
      use Membrane.Sink
      import Base.Sink, only: [def_options_with_default: 1, def_options_with_default: 0]
    end
  end

  defmacro def_options_with_default(further_options \\ []) do
    quote do
      def_options [
        unquote_splicing(further_options),
        tick: [
          type: :integer,
          spec: pos_integer,
          description:
            "Positive integer, describing number of ticks after which the message to count evaluate the throughput should be send"
        ],
        how_many_tries: [
          type: :integer,
          spec: pos_integer,
          description: "Positive integer, indicating how many meassurements should be made"
        ],
        numerator_of_probing_factor: [
          type: :integer,
          spec: pos_integer,
          description:
            "Numerator of the probing factor: X/Y meaning that X out of Y message passing times will be saved in the state."
        ],
        denominator_of_probing_factor: [
          type: :integer,
          spec: pos_integer,
          description:
            "Denominator of the probing factor: X/Y meaning that X out of Y message passing times will be saved in the state."
        ],
        should_produce_plots?: [
          type: :boolean,
          description:
            "True, if the result.svg containing the plot of the passing times for the messages should be printed, false otherwise"
        ],
        plots_path: [
          type: :string,
          description: "Path to the directory where the result plots should be stored"
        ],
        supervisor_pid: [type: :pid],
        metrics: [type: :list]
      ]
    end
  end

  def handle_init(opts) do
    metrics = opts.metrics |> Enum.filter(fn key -> key in @available_metrics end)
    #opts = %{opts| metrics: metrics}
    state = %{
      #opts: opts,
      #metrics: nil,
      #single_try_state: nil,
      #global_state: nil,


      message_count: 0,#SINGLE_STATE
      start_time: 0,#SINGLE_STATE
      tick: opts.tick,#OPTS
      how_many_tries: opts.how_many_tries,#OPTS
      tries_counter: 0,#GLOBAL_STATE
      sum: 0,#SINGLE_STATE
      squares_sum: 0,#SINGLE_STATE
      times: [],#SINGLE_STATE
      numerator_of_probing_factor: opts.numerator_of_probing_factor,#OPTS
      denominator_of_probing_factor: opts.denominator_of_probing_factor,#OPTS
      status: :playing,#SINGLE_STATE
      throughput: 0,#METRICS
      should_produce_plots?: opts.should_produce_plots?,#OPTS
      plots_path: opts.plots_path,#OPTS
      supervisor_pid: opts.supervisor_pid,#OPTS
      metrics: metrics,#OPTS
      passing_time_avg: 0,#METRICS
      passing_time_std: 0,#METRICS
      generator_frequency: 0,#METRICS
      result_metrics: []#GLOBAL_STATE
    }

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
        (state.squares_sum + state.message_count * passing_time_avg * passing_time_avg -
           2 * passing_time_avg * state.sum) /
          (state.message_count - 1)
      )

    state = %{
      state
      | passing_time_avg: passing_time_avg,
        passing_time_std: passing_time_std,
        generator_frequency: generator_frequency
    }

    state = write_demanded_metrics(state)

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
        send(state.supervisor_pid, {:result_metrics, Enum.reverse(state.result_metrics)})
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

  defp check_normality(
         _times,
         passing_time_avg,
         passing_time_std,
         _throughput,
         _generator_frequency,
         try_no
       ) do
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

  defp write_demanded_metrics(state) do
    if state.should_produce_plots? do
      output = Utils.prepare_plot(state.times, state.passing_time_avg, state.passing_time_std)

      File.write!(
        Path.join(
          state.plots_path,
          Integer.to_string(state.tries_counter) <> "_" <> @plot_filename
        ),
        output
      )
    end
    new_metrics = state.metrics |> Enum.map(fn key -> {key, Map.get(state, key)} end )
    state = %{state| result_metrics: [new_metrics| state.result_metrics]}
    state
  end

end
