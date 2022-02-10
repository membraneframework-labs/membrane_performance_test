defmodule Utils do
  def wait_for_complete(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _msg} ->
        IO.puts("Exit from #{inspect(pid)}")
    end
  end

  def prepare_plot(times, avg, std) do
    times = times |> Enum.map(fn {x, y} -> {x / 1000_000, y / 1000_000} end)
    ds = Contex.Dataset.new(times, ["x", "y"])
    point_plot = Contex.PointPlot.new(ds)

    plot =
      Contex.Plot.new(600, 400, point_plot)
      |> Contex.Plot.plot_options(%{legend_setting: :legend_right})
      |> Contex.Plot.titles(
        "AVG: #{:erlang.float_to_binary(avg / 1000_000, decimals: 3)} ms",
        "STD: #{:erlang.float_to_binary(std / 1000_000, decimals: 3)} ms"
      )
      |> Contex.Plot.axis_labels("Time of sending[ms]", "Passing time[ms]")

    {:safe, output} = Contex.Plot.to_svg(plot)
    output
  end
end
