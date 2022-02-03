defmodule Pipeline do
      use Membrane.Pipeline
      alias Membrane.ParentSpec
      alias Contex.{Dataset, BarChart, Plot}

      @impl true
      def handle_init(opts) do
        n = opts.n
        children = %{
          source: opts.source,
          sink: opts.sink
        }

        children =
          1..(n - 2)
          |> Enum.reduce(children, fn i, children_acc ->
            Map.put(children_acc, String.to_atom("filter#{i}"), %{opts.filter|id: i})
          end)

        links = [
          1..(n - 2)
          |> Enum.reduce(ParentSpec.link(:source), fn i, link_acc ->
            ParentSpec.to(link_acc, String.to_atom("filter#{i}"))
          end)
          |> ParentSpec.to(:sink)
        ]

        actions = [{:spec, %ParentSpec{children: children, links: links}}]
        {{:ok, actions}, %{n: opts.n, mails: %{}}}
      end

      @impl true
      def handle_notification(:stop, _element, _context, state) do
        Membrane.Pipeline.stop_and_terminate(self())
        {:ok, state}
      end

      @impl true
      def handle_notification({:play, specification}, _element, _context, state) do
        actions = [forward: {:source, {:play, specification}}]
        {{:ok, actions}, state}
      end

      @impl true
      def handle_notification(:flush, _element, _context, state) do
        actions = [forward: {:source, :flush}]
        {{:ok, actions}, state}
      end

      @impl true
      def handle_notification({:mails_update, id, number_of_mails}, _element, _context, state) do
        state = %{state|mails: state.mails |> Map.put(id, number_of_mails)}
        output = prepare_plot(state)
        File.write!(Path.absname("/Users/lukaszkita/membrane_performance_test/assets/result.svg"), output)
        {:ok, state}
      end

      defp prepare_plot(state) do
        data = 2..state.n-1 |> Enum.map(fn id -> {id, Map.get(state.mails, id, 0)  } end)
        ds = Dataset.new(data, ["id", "mails"])
        scale = Contex.ContinuousLinearScale.new()
        scale = Contex.ContinuousLinearScale.domain(scale, 1, 10000)
        point_plot = BarChart.new(ds, data_labels: false, custom_value_scale: scale)
        plot = Plot.new(600, 400, point_plot)
        |> Plot.plot_options(%{legend_setting: :legend_right})
        |> Plot.titles("Number of mails in mailbox", "in each filter")
        {:safe, output} = Plot.to_svg(plot)
        output
      end
end
