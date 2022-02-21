defmodule PullMode.Elements.Filter do
  use Membrane.Filter

  def_input_pad :input, demand_unit: :buffers, caps: :any
  def_output_pad :output, caps: :any

  def_options id: [
                type: :integer,
                spec: pos_integer,
                description: "Id of the element in the pipeline"
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
  def handle_demand(:output, size, :buffers, ctx, state) do
    # if length(Enum.to_list(ctx.pads.input.input_queue.q)) > 0 do
      #{:buffers, list} = Enum.at(Enum.to_list(ctx.pads.input.input_queue.q), 0)
      #IO.puts(list)
    # end


    #IO.puts("============================")
    #IO.inspect(Enum.count ctx.pads.input.input_queue.q)
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    {{:ok, [buffer: {:output, [buffer]}, redemand: :output]}, state}
  end
end
