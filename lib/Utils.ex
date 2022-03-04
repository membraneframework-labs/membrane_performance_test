defmodule Utils do
  @numerator_of_probing_factor 1
  @denominator_of_probing_factor 100

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

  def save_metrics(metrics, metrics_names, path, should_provide_metrics_header) do
    if should_provide_metrics_header do
      provide_results_file_header(metrics_names, path)
    end

    metrics_to_be_written_to_csv =
      metrics_names |> Enum.map(fn metric_name -> [:metrics, metric_name] end)

    content =
      metrics
      |> Enum.map(fn one_try_metrics ->
        one_try_metrics
        |> Enum.filter(fn {key, _value} -> key in metrics_to_be_written_to_csv end)
        |> Enum.map(fn {_key, value} -> value end)
        |> Enum.join(",")
      end)
      |> Enum.join("\n")

    File.write(
      path,
      content,
      [:append]
    )
  end

  def access_nested_map(map, list_of_keys) when length(list_of_keys) == 1 and is_map(map) do
    [key] = list_of_keys
    Map.get(map, key)
  end

  def access_nested_map(map, list_of_keys) when is_map(map) do
    [key | rest] = list_of_keys
    access_nested_map(Map.get(map, key), rest)
  end

  def access_nested_map(_map, _list_of_keys), do: nil

  def launch_test(opts) do
    module =
      case opts.mode do
        "pull" ->
          PullMode

        "push" ->
          PushMode

        "autodemand" ->
          AutoDemand

        value ->
          IO.puts("Unknown mode: #{value}")
      end

    chosen_metrics =
      prepare_information_to_be_fetched_from_sink_state(
        opts.chosen_metrics,
        opts.should_produce_plots
      )

    options = %{
      number_of_elements: opts.number_of_elements,
      source: nil,
      filter: Module.concat(module, Filter).__struct__(reductions: opts.reductions),
      sink:
        Module.concat(module, Sink).__struct__(
          tick: opts.tick,
          how_many_tries: opts.how_many_tries,
          numerator_of_probing_factor: @numerator_of_probing_factor,
          denominator_of_probing_factor: @denominator_of_probing_factor,
          should_produce_plots?: opts.should_produce_plots,
          plots_path: Map.get(opts, :plots_path),
          supervisor_pid: self(),
          chosen_metrics: chosen_metrics
        )
    }

    {initial_lower_bound, initial_upper_bound} =
      if opts.should_adjust_generator_frequency do
        {0, opts.inital_generator_frequency * 2}
      else
        {opts.inital_generator_frequency, opts.inital_generator_frequency}
      end

    options = %{
      options
      | source:
          Module.concat(module, Source).__struct__(
            initial_lower_bound: initial_lower_bound,
            initial_upper_bound: initial_upper_bound
          )
    }

    {:ok, pid} = Pipeline.start_link(options)
    Pipeline.play(pid)

    result_metrics = gather_metrics()
    Pipeline.stop_and_terminate(pid, blocking?: true)

    result_metrics
  end

  defp gather_metrics() do
    receive do
      {:new_metrics, new_metrics} -> [new_metrics | gather_metrics()]
      :finished -> []
    end
  end

  defp prepare_information_to_be_fetched_from_sink_state(chosen_metrics, should_prepare_plots) do
    chosen_metrics = chosen_metrics |> Enum.map(fn key -> [:metrics, key] end)

    chosen_metrics =
      chosen_metrics ++
        if should_prepare_plots do
          [
            [:single_try_state, :times],
            [:metrics, :passing_time_avg],
            [:metrics, :passing_time_std]
          ]
        else
          []
        end

    MapSet.new(chosen_metrics) |> MapSet.to_list()
  end

  defp provide_results_file_header(metrics_names, path) do
    content = (metrics_names |> Enum.join(",")) <> "\n"

    File.write(
      path,
      content,
      [:append]
    )
  end
end
