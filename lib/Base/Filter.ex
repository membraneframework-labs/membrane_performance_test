defmodule Base.Filter do
  defmacro __using__(_opts) do
    quote do
      use Membrane.Filter
      import Base.Filter, only: [def_options_with_default: 1, def_options_with_default: 0]
    end
  end

  defmacro def_options_with_default(further_options \\ []) do
    quote do
      def_options [
        unquote_splicing(further_options),
        id: [
          type: :integer,
          spec: pos_integer,
          description: "Id of the element in the pipeline"
        ],
        reductions: [
          type: :integer,
          spec: pos_integer,
          description: "Number of reductions which should be done while processing each buffer"
        ]
      ]
    end
  end

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
