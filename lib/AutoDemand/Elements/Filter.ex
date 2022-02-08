defmodule AutoDemand.Elements.Filter do
  use Membrane.Filter

  def_input_pad :input, demand_mode: :auto, caps: :any
  def_output_pad :output, demand_mode: :auto, caps: :any
  def_options [
    id: [type: :integer, spec: pos_integer, description: "Id of the element in the pipeline"]
  ]

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
