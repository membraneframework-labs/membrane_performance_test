defmodule Base.Filter do
  def handle_init(opts) do
    reductions_function = Reductions.prepare_desired_function(opts.reductions)
    {:ok, %{reductions_function: reductions_function}}
  end

  def handle_caps(:input, _caps, _context, state) do
    {{:ok, caps: :any}, state}
  end

  def handle_process(:input, buffer, _ctx, state) do
    state.reductions_function.()
    {{:ok, [buffer: {:output, [buffer]}]}, state}
  end
end
