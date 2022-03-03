defmodule Utils do
  def wait_for_complete(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _msg} -> nil
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

  def save_statistics(statistics, statistics_names, path, should_provide_statistics_header) do
    if should_provide_statistics_header do
      provide_results_file_header(statistics_names, path)
    end

    content  = statistics |> Enum.map(fn one_try_statistics -> one_try_statistics |> Enum.map(fn {_key, value}->value end)  |> Enum.join(",") end) |> Enum.join("\n")

    File.write(
      path,
      content,
      [:append]
    )
  end

  defp provide_results_file_header(statistics_names, path) do
    content = (statistics_names |> Enum.join(",")) <> "\n"

    File.write(
      path,
      content,
      [:append]
    )
  end
end
