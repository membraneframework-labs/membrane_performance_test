defmodule PushMode.Sink do
  use Base.Sink

  def_input_pad :input,
    caps: :any,
    mode: :push

  def_options_with_default()

  @impl true
  def handle_init(opts) do
    Base.Sink.handle_init(opts)
  end

  @impl true
  def handle_write(:input, buffer, ctx, state) do
    Base.Sink.handle_write(:input, buffer, ctx, state)
  end

  @impl true
  def handle_other(:tick, ctx, state) do
    Base.Sink.handle_other(:tick, ctx, state)
  end
end
