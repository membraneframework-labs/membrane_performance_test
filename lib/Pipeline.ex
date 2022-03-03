defmodule Pipeline do
  use Membrane.Pipeline
  alias Membrane.ParentSpec
  @toilet_capacity 400
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
        Map.put(children_acc, String.to_atom("filter#{i}"), %{opts.filter | id: i})
      end)

    links = [
      1..(n - 2)
      |> Enum.reduce(
        ParentSpec.link(:source) |> via_in(:input, toilet_capacity: @toilet_capacity),
        fn i, link_acc ->
          ParentSpec.to(link_acc, String.to_atom("filter#{i}"))
        end
      )
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
end
