defmodule PushMode.Elements.Source do
  use Membrane.Source

  alias Membrane.Buffer
  alias Membrane.Time

  def_output_pad :output, mode: :push, caps: :any

  def_options initial_lower_bound: [
                type: :integer,
                spec: pos_integer,
                description:
                  "Initial lower bound for binsearching of the message generator frequency"
              ],
              initial_upper_bound: [
                type: :integer,
                spec: pos_integer,
                description:
                  "Initial upper bound for binsearching of the message generator frequency"
              ]

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
