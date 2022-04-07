defmodule PushMode.Filter do
  use Base.Filter

  def_input_pad :input, caps: :any, mode: :push
  def_output_pad :output, caps: :any, mode: :push

  def_options_with_default()

  @impl true
  def handle_init(opts) do
    Base.Filter.handle_init(opts)
  end

  @impl true
  def handle_caps(:input, caps, ctx, state) do
    Base.Filter.handle_caps(:input, caps, ctx, state)
  end

  @impl true
  def handle_process(:input, buffer, ctx, state) do
    Base.Filter.handle_process(:input, buffer, ctx, state)
  end
end
