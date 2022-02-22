defmodule Base.Filter do
  def handle_init(_opts) do
    {:ok, %{}}
  end

  def handle_caps(:input, _caps, _context, state) do
    {{:ok, caps: :any}, state}
  end

  def handle_process(:input, buffer, _ctx, state) do
    {{:ok, [buffer: {:output, [buffer]}]}, state}
  end
end
