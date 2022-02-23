defmodule PullMode.Filter do
  use Base.Filter

  def_input_pad :input, demand_unit: :buffers, caps: :any
  def_output_pad :output, caps: :any

  def_options_with_default()

  @impl true
  def handle_init(opts) do
    Base.Filter.handle_init(opts)
  end

  @impl true
  def handle_caps(:input, caps, context, state) do
    Base.Filter.handle_caps(:input, caps, context, state)
  end

  @impl true
  def handle_process(:input, buffer, ctx, state) do
    {{:ok, actions}, state} = Base.Filter.handle_process(:input, buffer, ctx, state)
    actions = actions ++ [redemand: :output]
    {{:ok, actions}, state}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end
end
