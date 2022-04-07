defmodule Base.Sink do
  alias Membrane.Buffer

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
            "Positive integer, describing number of ticks after which the message to calculate the throughput should be send"
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
            "True, if the .svg files containing the plots of the passing times for the messages should be printed, false otherwise"
        ],
        supervisor_pid: [
          type: :pid,
          description:
            "PID of the process which should be informed about the metrics gathered during the test. After the test is finished, that process
        will receive {:result_metrics, metrics_list} message."
        ],
        chosen_metrics: [
          type: :list,
          description: "List of atoms corresponding to available metrics"
        ]
      ]
    end
  end

  def handle_init(opts) do
    state = %{
      opts: opts,
      metrics: %{throughput: 0, passing_time_avg: 0, passing_time_std: 0, generator_frequency: 0},
      single_try_state: %{
        message_count: 0,
        start_time: 0,
        sum: 0,
        squares_sum: 0,
        times: []
      },
      global_state: %{result_metrics: [], tries_counter: 0, status: :playing}
    }

    {:ok, state}
  end

  def handle_write(:input, buffer, _context, state) when state.global_state.status == :playing do
    state =
      if state.single_try_state.message_count == 0 do
        Process.send_after(self(), :tick, state.opts.tick)

        %{
          state
          | single_try_state: %{
              state.single_try_state
              | start_time: Membrane.Time.monotonic_time()
            }
        }
      else
        state
      end

    time = Membrane.Time.monotonic_time() - buffer.pts

    state =
      if :rand.uniform(state.opts.denominator_of_probing_factor) <=
           state.opts.numerator_of_probing_factor do
        single_try_state =
          Map.update!(
            state.single_try_state,
            :times,
            &[{buffer.pts - state.single_try_state.start_time, time} | &1]
          )

        %{state | single_try_state: single_try_state}
      else
        state
      end

    single_try_state = Map.update!(state.single_try_state, :message_count, &(&1 + 1))
    single_try_state = Map.update!(single_try_state, :sum, &(&1 + time))
    single_try_state = Map.update!(single_try_state, :squares_sum, &(&1 + time * time))
    {{:ok, []}, %{state | single_try_state: single_try_state}}
  end

  def handle_write(
        :input,
        %Buffer{payload: :flush, metadata: generator_frequency},
        _ctx,
        state
      )
      when state.global_state.status == :flushing do
    passing_time_avg = state.single_try_state.sum / state.single_try_state.message_count

    passing_time_std =
      :math.sqrt(
        (state.single_try_state.squares_sum +
           state.single_try_state.message_count * passing_time_avg * passing_time_avg -
           2 * passing_time_avg * state.single_try_state.sum) /
          (state.single_try_state.message_count - 1)
      )

    state = %{
      state
      | metrics: %{
          state.metrics
          | passing_time_avg: passing_time_avg,
            passing_time_std: passing_time_std,
            generator_frequency: generator_frequency
        }
    }

    write_demanded_metrics(state)

    # the first run is the warm-up run
    specification =
      if state.global_state.tries_counter == 0 do
        :the_same
      else
        check_normality(
          state.single_try_state.times,
          passing_time_avg,
          passing_time_std,
          state.metrics.throughput,
          generator_frequency
        )
      end

    actions =
      if state.global_state.tries_counter == state.opts.how_many_tries do
        send(
          state.opts.supervisor_pid,
          :finished
        )

        []
      else
        [notify: {:play, specification}]
      end

    format = [
      bar_color: [IO.ANSI.white(), IO.ANSI.green_background()],
      blank_color: IO.ANSI.red_background()
    ]
    throughput_string = " THROUGHPUT: #{:erlang.float_to_binary(state.metrics.throughput, decimals: 2)} msg/s "
    ProgressBar.render(
      state.global_state.tries_counter + 1,
      state.opts.how_many_tries + 1,
      throughput_string,
      format
    )

    state = %{
      state
      | single_try_state: %{
          state.single_try_state
          | message_count: 0,
            sum: 0,
            squares_sum: 0,
            times: []
        },
        global_state: %{
          state.global_state
          | tries_counter: state.global_state.tries_counter + 1,
            status: :playing
        }
    }

    {{:ok, actions}, state}
  end

  def handle_write(:input, _msg, _ctx, state) when state.global_state.status == :flushing do
    {{:ok, []}, state}
  end

  def handle_other(:tick, _ctx, state) do
    elapsed =
      (Membrane.Time.monotonic_time() - state.single_try_state.start_time) /
        Membrane.Time.second()

    throughput = state.single_try_state.message_count / elapsed

    {actions, state} =
      {[notify: :flush], %{state | global_state: %{state.global_state | status: :flushing}}}

    state = %{state | metrics: %{state.metrics | throughput: throughput}}
    {{:ok, actions}, state}
  end

  defp check_normality(
         _times,
         passing_time_avg,
         passing_time_std,
         _throughput,
         _generator_frequency
       ) do
    cond do
      # average passing time of a message is greater than 20ms which is unacceptable, therfore we need to slow down the message generation
      passing_time_avg > 20_000_000 ->
        :slower

      # average passing time of a message is less than 20ms, but the standard deviation is relatively too high
      passing_time_std > 10_000_000 and passing_time_std > 0.5 * passing_time_avg ->
        :slower

      true ->
        :faster
    end
  end

  defp write_demanded_metrics(state) do
    new_metrics =
      state.opts.chosen_metrics
      |> Enum.map(fn key -> {key, Bunch.Access.get_in(state, key)} end)
      |> Map.new()

    send(
      state.opts.supervisor_pid,
      {:new_metrics, new_metrics}
    )
  end
end
