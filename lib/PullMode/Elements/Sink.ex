defmodule PullMode.Elements.Sink do
  use Membrane.Sink

  def_options tick: [
    type: :integer,
    spec: pos_integer,
    description:
      "Positive integer, describing number of ticks after which the message to count evaluate the throughput should be send"
  ]

  def_input_pad :input,
    caps: :any,
    demand_unit: :buffers

  @impl true
  def handle_init(opts) do
    {:ok, %{message_count: 0, start_time: 0, tick: opts.tick}}
  end

  @impl true
  def handle_prepared_to_playing(_context, state) do
    {{:ok, demand: :input}, state}
  end

  @impl true
  def handle_write(:input, _buffer, _context, state) do
    state =
      if state.message_count == 0 do
        Process.send_after(self(), :tick, state.tick)
        %{state | start_time: Membrane.Time.monotonic_time()}
      else
        state
      end

    {{:ok, demand: :input}, Map.update!(state, :message_count, &(&1 + 1))}
  end

  @impl true
  def handle_other(:tick, _ctx, state) do
    elapsed = (Membrane.Time.monotonic_time() - state.start_time) / Membrane.Time.second()
    IO.inspect("[PULL MODE] Elapsed: #{elapsed} [s] Messages: #{state.message_count / elapsed} [M/s]")
    {:ok, %{state | message_count: 0}}
  end
end