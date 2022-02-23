defmodule PushMode.Source do
  use Base.Source

  def_output_pad :output, mode: :push, caps: :any

  def_options_with_default()

  @impl true
  def handle_init(opts) do
    Base.Source.handle_init(opts)
  end

  @impl true
  def handle_prepared_to_playing(ctx, state) do
    Base.Source.handle_prepared_to_playing(ctx, state)
  end

  @impl true
  def handle_tick(:next_buffer_timer, ctx, state = %{status: :playing}) do
    Base.Source.handle_tick(:next_buffer_timer, ctx, state)
  end

  @impl true
  def handle_other(msg, ctx, state) do
    Base.Source.handle_other(msg, ctx, state)
  end
end
