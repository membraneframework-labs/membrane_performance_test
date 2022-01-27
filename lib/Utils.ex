defmodule Utils do
  def wait_for_complete(pid) do
    ref = Process.monitor(pid)
    receive do
      {:DOWN, ^ref, :process, ^pid, _msg} ->
        IO.puts("Exit from #{inspect(pid)}")
    end
  end

  defmacro inject_pipeline(mode) do
    quote do
      alias  unquote(mode).Elements.Source
      alias  unquote(mode).Elements.Sink
      alias  unquote(mode).Elements.Filter
      use Membrane.Pipeline
      alias Membrane.ParentSpec

      @impl true
      def handle_init(opts) do

        n = opts.n

        children = %{
          source: Source,
          sink: %Sink{tick: opts.tick}
        }

        children =
          1..(n - 2)
          |> Enum.reduce(children, fn i, children_acc ->
            Map.put(children_acc, String.to_atom("filter#{i}"), Filter)
          end)

        links = [
          1..(n - 2)
          |> Enum.reduce(ParentSpec.link(:source), fn i, link_acc ->
            ParentSpec.to(link_acc, String.to_atom("filter#{i}"))
          end)
          |> ParentSpec.to(:sink)
        ]

        actions = [{:spec, %ParentSpec{children: children, links: links}}]
        {{:ok, actions}, %{}}
      end
    end
  end
end
