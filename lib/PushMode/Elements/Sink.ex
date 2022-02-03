defmodule PushMode.Elements.Sink do
  use Membrane.Sink

  alias Membrane.Buffer
  @flush_buffer %Buffer{payload: :flush}


  def_input_pad :input,
    caps: :any,
    mode: :push

  def_options [
    tick: [type: :integer, spec: pos_integer, description: "Positive integer, describing number of ticks after which the message to count evaluate the throughput should be send"],
    how_many_tries: [type: :integer, spec: pos_integer, description: "Positive integer, indicating how many meassurements should be made"],
    a: [],
    b: []
  ]

  @impl true
  def handle_init(opts) do
    {:ok, %{message_count: 0, start_time: 0, tick: opts.tick,
     how_many_tries: opts.how_many_tries,
     tries_counter: 1, sum: 0, squares_sum: 0,
     times: [], a: opts.a, b: opts.b,
     status: :playing}}
  end

  @impl true
  def handle_write(:input, buffer, _context, state=%{status: :playing}) do
    state =
      if state.message_count == 0 do
        Process.send_after(self(), :tick, state.tick)
        %{state | start_time: Membrane.Time.monotonic_time()}
      else
        state
      end
    time = Membrane.Time.monotonic_time() - buffer.dts
    state = if :rand.uniform(state.b)<=state.a do
      Map.update!(state, :times, &([{buffer.dts-state.start_time, time} | &1]))
      else
        state
      end
    state = Map.update!(state, :message_count, &(&1 + 1))
    state = Map.update!(state, :sum, &(&1 + time))
    state = Map.update!(state, :squares_sum, &(&1 + time*time))
    {:ok, state}
  end

  @impl true
  def handle_write(:input, @flush_buffer, _ctx, state=%{status: :flushing}) do
    state = %{state|  message_count: 0, sum: 0, squares_sum: 0, times: [], tries_counter: state.tries_counter+1, status: :playing}
    actions = [notify: :play]
    {{:ok, actions}, state}
  end

  @impl true
  def handle_write(:input, _msg, _ctx, state=%{status: :flushing}) do
    {:ok, state}
  end

  @impl true
  def handle_other(:tick, _ctx, state) do
    elapsed = (Membrane.Time.monotonic_time() - state.start_time) / Membrane.Time.second()
    avg = state.sum/state.message_count
    std = :math.sqrt((state.squares_sum+state.message_count*avg*avg-2*avg*state.sum)/(state.message_count-1))
    IO.inspect("AVG: #{avg} STD: #{std} [us]")
    IO.inspect(
      "[PUSH MODE] Mailbox: #{Process.info(self())[:message_queue_len]} Elapsed: #{elapsed} [s] Messages: #{state.message_count / elapsed} [M/s] TRY: #{state.tries_counter}"
    )
    output = prepare_plot(state.times)
    File.write!(Path.absname("/Users/lukaszkita/membrane_performance_test/assets/result2.svg"), output)

    {actions, state} = if state.tries_counter==state.how_many_tries do
      {[notify: :stop], state}
    else
      {[notify: :flush], %{state| status: :flushing}}
    end
    {{:ok, actions}, state}
  end

  @impl true
  def handle_other(:wait_for_flush, _ctx, state=%{status: :playing}) do
    state = %{state| status: :flushing}
    {:ok, state}
  end

  defp prepare_plot(times) do
    ds = Contex.Dataset.new(times, ["x", "y"])
    point_plot = Contex.PointPlot.new(ds)
    plot = Contex.Plot.new(600, 400, point_plot)
    |> Contex.Plot.plot_options(%{legend_setting: :legend_right})
    |> Contex.Plot.titles("Waiting time", "")
    {:safe, output} = Contex.Plot.to_svg(plot)
    output
  end

end
