defmodule PushMode.Elements.Source do
  use Membrane.Source

  alias Membrane.Buffer

  @message :crypto.strong_rand_bytes(1000)

  @interval 10

  # n = 3
  @messages_per_second 170_000
  # n = 4
  @messages_per_second 110_000
  # n = 5
  @messages_per_second 95_000
  # n = 6
  @messages_per_second 90_000
  # n = 7
  @messages_per_second 80_000
  # n = 8
  @messages_per_second 75_000
  # n = 9
  @messages_per_second 75_000
  # n = 10
  @messages_per_second 60_000
  # n = 15
  @messages_per_second 45_000
  # n = 20
  @messages_per_second 40_000
  # n = 25
  @messages_per_second 25_000
  # n = 30
  @messages_per_second 25_000

  def_output_pad :output, mode: :push, caps: :any

  @impl true
  def handle_init(_opts) do
    messages = (@messages_per_second * @interval / 1000) |> trunc()
    {:ok, %{messages: messages}}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    Process.send_after(self(), :next_buffer, @interval)
    {:ok, state}
  end

  @impl true
  def handle_other(:next_buffer, _ctx, state) do
    buffers = for _i <- 1..state.messages, do: %Buffer{payload: @message}
    actions = [buffer: {:output, buffers}]
    Process.send_after(self(), :next_buffer, @interval)
    {{:ok, actions}, state}
  end
end
