defmodule Mix.Tasks.PerformanceTest do
  use Mix.Task
  @numerator_of_probing_factor 1
  @denominator_of_probing_factor 100
  @syntax_error_message "Wrong syntax! Try: mix performance_test --mode <push|pull|autodemand> --n <number of elements>
   --howManyTries <how many tries> --tick <single try length [ms]> --initialGeneratorFrequency <frequency of the message generator in the first run>
   --metrics <comma separated list of statistic names which should be saved> --reductions <number of reductions to be performed in each filter, while processing buffer>
   OPTIONAL: [--shouldAdjustGeneratorFrequency, --shouldProducePlots, --shouldProvidemetricsHeader]
   ARG: <output directory path>"
  @strict_keywords_list [
    mode: :string,
    n: :integer,
    howManyTries: :integer,
    tick: :integer,
    initalGeneratorFrequency: :integer,
    metrics: :string,
    reductions: :integer
  ]
  @optional_keywords_list [
    shouldAdjustGeneratorFrequency: :boolean,
    shouldProducePlots: :boolean,
    shouldProvidemetricsHeader: :boolean
  ]
  @metrics_filename "stats.csv"
  @plots_directory "plots"
  def run(args) do
    {options, arguments, errors} =
      OptionParser.parse(args, strict: @strict_keywords_list ++ @optional_keywords_list)

    if errors != [] or length(arguments) != 1 or
         Enum.any?(@strict_keywords_list, fn {key, _value} ->
           not Keyword.has_key?(options, key)
         end) do
      IO.puts(args)
      IO.puts(@syntax_error_message)
    else
      mode = Keyword.get(options, :mode)
      n = Keyword.get(options, :n)
      how_many_tries = Keyword.get(options, :howManyTries)
      tick = Keyword.get(options, :tick)
      inital_generator_frequency = Keyword.get(options, :initalGeneratorFrequency)
      should_adjust_generator_frequency = Keyword.get(options, :shouldAdjustGeneratorFrequency)
      should_produce_plots = Keyword.get(options, :shouldProducePlots)
      should_provide_metrics_header = Keyword.get(options, :shouldProvidemetricsHeader)
      metrics = Keyword.get(options, :metrics) |> parse_metrics()
      reductions = Keyword.get(options, :reductions)
      [output_directory_path] = arguments

      result_metrics =
        launch_test(%{
          mode: mode,
          n: n,
          how_many_tries: how_many_tries,
          tick: tick,
          inital_generator_frequency: inital_generator_frequency,
          should_adjust_generator_frequency: should_adjust_generator_frequency,
          should_produce_plots: should_produce_plots,
          metrics: metrics,
          reductions: reductions,
          plots_path: Path.join(output_directory_path, @plots_directory)
        })

      Utils.save_metrics(
        result_metrics,
        metrics,
        Path.join(output_directory_path, @metrics_filename),
        should_provide_metrics_header
      )
    end
  end

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
          IO.puts(@syntax_error_message)
      end

    options = %{
      n: opts.n,
      source: nil,
      filter: Module.concat(module, Filter).__struct__(id: -1, reductions: opts.reductions),
      sink:
        Module.concat(module, Sink).__struct__(
          tick: opts.tick,
          how_many_tries: opts.how_many_tries,
          numerator_of_probing_factor: @numerator_of_probing_factor,
          denominator_of_probing_factor: @denominator_of_probing_factor,
          should_produce_plots?: opts.should_produce_plots,
          plots_path: opts.plots_path,
          supervisor_pid: self(),
          metrics: opts.metrics
        )
    }

    if opts.should_adjust_generator_frequency do
      initial_lower_bound = 0
      initial_upper_bound = opts.inital_generator_frequency * 2

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

      receive do
        {:result_metrics, result_metrics} -> result_metrics
      end
    else
      options = %{
        options
        | source:
            Module.concat(module, Source).__struct__(
              initial_lower_bound: opts.inital_generator_frequency,
              initial_upper_bound: opts.inital_generator_frequency
            )
      }

      {:ok, pid} = Pipeline.start_link(options)
      Pipeline.play(pid)

      receive do
        {:result_metrics, result_metrics} -> result_metrics
      end
    end
  end

  defp parse_metrics(metrics_string) do
    for statistic_name <- metrics_string |> String.split(",") do
      String.to_atom(statistic_name)
    end
  end
end
