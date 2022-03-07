defmodule Utils do
  @moduledoc """
  A module gathering function which provide functionalities used in different other modules.
  """
  @numerator_of_probing_factor 1
  @denominator_of_probing_factor 100


  @type single_run_metrics :: %{list(any()) => any()}

  defmodule TestOptions do
    @enforce_keys [:mode, :number_of_elements, :how_many_tries, :tick, :inital_generator_frequency, :should_adjust_generator_frequency, :should_produce_plots, :chosen_metrics, :reductions]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
      mode: String.t(),
      number_of_elements: integer(),
      how_many_tries: integer(),
      tick: integer(),
      inital_generator_frequency: integer(),
      should_adjust_generator_frequency: integer(),
      should_produce_plots: boolean(),
      chosen_metrics: list(atom()),
      reductions: integer()
    }
  end


  @doc """
  Starts monitoring the process with given `pid` and waits until it terminates and sends `:DOWN` message
  """
  @spec wait_for_complete(pid()) :: nil
  def wait_for_complete(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _msg} -> nil
    end
  end


  @doc """
  Creates an .svg representation of a HowLongWasAMessagePassingThroughThePipeline(time_when_message_was_sent) plot with the use of ContEx library, based on the probe of points, the average time spent by a message in the pipeline, and the standard deviation of that value.
  Args:
    times - list of {x, y} tuples, where x is a time the message was sent and y is duration of the time period which elapsed between the message generation and that message arrival on the sink
    avg - average time messages spent in the pipeline
    std - standard deviation of the time messages spent in the pipeline
  """
  @spec prepare_plot(list({integer(), integer()}), float(), float()) :: any()
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


  @doc """
  Saves the test results in the filesystem, as a .csv file.
  Args:
    metrics - list of metrics gathered during a single test run, a value returned by `Utils.launch_test/1`,
    metric_names - list of atoms describing the names of the metrics which should be saved in the filesystem,
    path - path to the file where the result metrics should be stored,
    should_provide_metrics_headers - `true` if the first line in the result file should contain the names of metrics, `false` otherwise.
  """
  @spec save_metrics(list(single_run_metrics()), list(atom()), String.t(), boolean()) :: :ok | {:error, any()}
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


  @doc """
  Gets the value from the inner dictionaries of a nested dictionary.
  A nested dictionary is a dictionary whose values are some other (potentially also nested) dictionaries.
  Args:
    map - a nested dictionary,
    list_of_keys - list of keys which point to the desired value of some inner dictionary
  Returns: a value in the `map`, pointed by the `list_of_keys`.
  """
  @spec access_nested_map(map(), list(any)) :: any()
  def access_nested_map(map, list_of_keys) when length(list_of_keys) == 1 and is_map(map) do
    [key] = list_of_keys
    Map.get(map, key)
  end

  def access_nested_map(map, list_of_keys) when is_map(map) do
    [key | rest] = list_of_keys
    access_nested_map(Map.get(map, key), rest)
  end

  def access_nested_map(_map, _list_of_keys), do: nil


  @doc """
  Launches a test parametrized with the Utils.TestOptions structure and returns the metrics gathered during that test.
  Args:
    opts - TestOptions structure describing the parameters of the test.
  Returns: a list of maps, where each map describes the metrics gathered during a single try of the test. The keys in each of these maps are lists of keys pointing to the desired information
  in the internal state of Sink, and the value is the desired information. Exemplary maps describing the metrics gather during a single run:
  ```
    %{
      [:metrics, :generator_frequency] => 4375,
      [:metrics, :passing_time_avg] => 3112845.262290126,
      [:metrics, :passing_time_std] => 625614.153995784,
    }
  ```
  """
  @spec launch_test(TestOptions.t()) :: list(single_run_metrics)
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
