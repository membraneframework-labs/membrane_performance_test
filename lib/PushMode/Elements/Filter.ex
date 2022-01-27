defmodule PushMode.Elements.Filter do
  use Membrane.Filter

  def_input_pad :input, caps: :any, mode: :push
  def_output_pad :output, caps: :any, mode: :push

  @impl true
  def handle_init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_caps(:input, _caps, _context, state) do
    {{:ok, caps: :any}, state}
  end

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    {{:ok, [buffer: {:output, [buffer]}]}, state}
  end
end
