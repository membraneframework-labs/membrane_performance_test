defmodule PullMode.Elements.Source do
  use Membrane.Source

  alias Membrane.Buffer

  @message :crypto.strong_rand_bytes(1000)

  def_output_pad :output, caps: :any

  @impl true
  def handle_init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    buffers =
      1..size
      |> Enum.map(fn _i -> %Buffer{payload: @message, dts: Membrane.Time.monotonic_time()} end)

    actions = [buffer: {:output, buffers}]
    {{:ok, actions}, state}
  end
end
