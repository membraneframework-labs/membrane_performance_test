defmodule PushMode.Elements.Sink do
  use Membrane.Sink

  alias Membrane.Buffer

  @plot_path "result.svg"

  def_input_pad :input,
    caps: :any,
    mode: :push

  def_options tick: [
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
              output_directory: [
                type: :string,
                description: "Path to the directory where the results will be stored"
              ],
              supervisor_pid: [type: :pid]

  @impl true
  def handle_init(opts) do
    {:ok,
     %{
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
       supervisor_pid: opts.supervisor_pid
     }}
  end

  @impl true
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
    {:ok, state}
  end

  @impl true
  def handle_write(
        :input,
        %Buffer{payload: :flush, metadata: generator_frequency},
        _ctx,
        state = %{status: :flushing}
      ) do
    avg = state.sum / state.message_count

    std =
      :math.sqrt(
        (state.squares_sum + state.message_count * avg * avg - 2 * avg * state.sum) /
          (state.message_count - 1)
      )

    if state.should_produce_plots? do
      output = Utils.prepare_plot(state.times, avg, std)
      File.write!(Integer.to_string(state.tries_counter) <> "_" <> @plot_path, output)
    end

    specification =
      check_normality(
        state.times,
        avg,
        std,
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

  @impl true
  def handle_write(:input, _msg, _ctx, state = %{status: :flushing}) do
    {:ok, state}
  end

  @impl true
  def handle_other(:tick, _ctx, state) do
    elapsed = (Membrane.Time.monotonic_time() - state.start_time) / Membrane.Time.second()
    throughput = state.message_count / elapsed

    IO.puts(
      "[PUSH MODE][TRY: #{state.tries_counter}]Mailbox: #{Process.info(self())[:message_queue_len]} Elapsed: #{elapsed} [s] Messages: #{throughput} [msg/s]"
    )

    File.write!(
      Path.join(state.output_directory, "result.txt"),
      Float.to_string(throughput) <> "\n",
      [:append]
    )

    {actions, state} = {[notify: :flush], %{state | status: :flushing}}

    state = %{state | throughput: throughput}
    {{:ok, actions}, state}
  end

  defp check_normality(_times, avg, std, throughput, generator_frequency, try_no) do
    cond do
      try_no == 0 ->
        :the_same

      # throughput < 0.5*generator_frequency -> IO.puts("first #{throughput} #{generator_frequency}")
      #  :slower
      avg > 20_000_000 ->
        IO.puts("second #{avg}")
        :slower

      std > 10_000_000 and std > 0.5 * avg ->
        IO.puts("third: #{avg}, #{std}")
        :slower

      true ->
        :faster
    end
  end
end
