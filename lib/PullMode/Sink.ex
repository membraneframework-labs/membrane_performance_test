defmodule PullMode.Sink do
  use Base.Sink

  def_input_pad :input,
    caps: :any,
    demand_unit: :buffers

  def_options_with_default()

  @impl true
  def handle_init(opts) do
    Base.Sink.handle_init(opts)
  end

  @impl true
  def handle_write(:input, buffer, ctx, state) do
    {{:ok, actions}, state} = Base.Sink.handle_write(:input, buffer, ctx, state)
    actions = actions ++ [demand: {:input, 1}]
    {{:ok, actions}, state}
  end

  @impl true
  def handle_other(:tick, ctx, state) do
    Base.Sink.handle_other(:tick, ctx, state)
  end

  @impl true
  def handle_prepared_to_playing(_context, state) do
    {{:ok, demand: {:input, 1}}, state}
  end
end
