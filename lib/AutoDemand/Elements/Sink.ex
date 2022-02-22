defmodule AutoDemand.Elements.Sink do
  use Membrane.Sink

  def_input_pad :input,
    caps: :any,
    demand_unit: :buffers

  def_options tick: [
                type: :integer,
                spec: pos_integer,
                description:
                  "Positive integer, describing number of ticks after which the message to count evaluate the throughput should be send"
              ],
              how_many_tries: [
                type: :integer,
                spec: pos_integer,
                description: "Positive integer, indicating how many meassurements should be made"
              ],
              numerator_of_probing_factor: [
                type: :integer,
                spec: pos_integer,
                description:
                  "Numerator of the probing factor: X/Y meaning that X out of Y message passing times will be saved in the state."
              ],
              denominator_of_probing_factor: [
                type: :integer,
                spec: pos_integer,
                description:
                  "Denominator of the probing factor: X/Y meaning that X out of Y message passing times will be saved in the state."
              ],
              should_produce_plots?: [
                type: :boolean,
                description:
                  "True, if the result.svg containing the plot of the passing times for the messages should be printed, false otherwise"
              ],
              output_directory: [
                type: :string,
                description: "Path to the directory where the results will be stored"
              ],
              supervisor_pid: [type: :pid],
              statistics: [type: :list],
              provide_statistics_header?: [type: :boolean]

  @impl true
  def handle_init(opts) do
    Base.Sink.handle_init(opts)
  end

  @impl true
  def handle_write(:input, buffer, ctx, state) do
    {{:ok, actions}, state} = Base.Sink.handle_write(:input, buffer, ctx, state)
    actions = actions ++ [demand: {:input, 1}]
    {{:ok, actions}, state}
  end

  @impl true
  def handle_other(:tick, ctx, state) do
    Base.Sink.handle_other(:tick, ctx, state)
  end

  @impl true
  def handle_prepared_to_playing(_context, state) do
    {{:ok, demand: {:input, 1}}, state}
  end
end
