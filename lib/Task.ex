defmodule Mix.Tasks.PerformanceTest do
  use Mix.Task

  @syntax_error_message "Wrong syntax! Try: mix performance_test --mode <push|pull|autodemand> --n <number of elements>
   --howManyTries <how many tries> --tick <single try length [ms]> --initialGeneratorFrequency <frequency of the message generator in the first run>
   --chosenMetrics <comma separated list of statistic names which should be saved> --reductions <number of reductions to be performed in each filter, while processing buffer>
   OPTIONAL: [--shouldAdjustGeneratorFrequency, --shouldProducePlots, --shouldProvidemetricsHeader]
   ARG: <output directory path>"
  @strict_keywords_list [
    mode: :string,
    numberOfElements: :integer,
    howManyTries: :integer,
    tick: :integer,
    initalGeneratorFrequency: :integer,
    chosenMetrics: :string,
    reductions: :integer
  ]
  @optional_keywords_list [
    shouldAdjustGeneratorFrequency: :boolean,
    shouldProducePlots: :boolean,
    shouldProvideMetricsHeader: :boolean
  ]
  @metrics_filename "stats.csv"
  @plots_directory "plots"
  @available_metrics [
    :throughput,
    :generator_frequency,
    :passing_time_avg,
    :passing_time_std
  ]
  @plot_filename "plot.svg"

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
      number_of_elements = Keyword.get(options, :numberOfElements)
      how_many_tries = Keyword.get(options, :howManyTries)
      tick = Keyword.get(options, :tick)
      inital_generator_frequency = Keyword.get(options, :initalGeneratorFrequency)
      should_adjust_generator_frequency = Keyword.get(options, :shouldAdjustGeneratorFrequency)
      should_produce_plots = Keyword.get(options, :shouldProducePlots)
      should_provide_metrics_header = Keyword.get(options, :shouldProvideMetricsHeader)
      chosen_metrics = Keyword.get(options, :chosenMetrics) |> change_metric_strings_into_atoms()
      reductions = Keyword.get(options, :reductions)
      [output_directory_path] = arguments

      result_metrics =
        Utils.launch_test(%{
          mode: mode,
          number_of_elements: number_of_elements,
          how_many_tries: how_many_tries,
          tick: tick,
          inital_generator_frequency: inital_generator_frequency,
          should_adjust_generator_frequency: should_adjust_generator_frequency,
          should_produce_plots: should_produce_plots,
          chosen_metrics: chosen_metrics,
          reductions: reductions,
          plots_path: Path.join(output_directory_path, @plots_directory)
        })

      Utils.save_metrics(
        result_metrics,
        chosen_metrics,
        Path.join(output_directory_path, @metrics_filename),
        should_provide_metrics_header
      )

      if should_produce_plots do
        result_metrics
        |> Enum.with_index()
        |> Enum.each(fn {single_try_list_of_metrics, i} ->
          output =
            Utils.prepare_plot(
              single_try_list_of_metrics[[:single_try_state, :times]],
              single_try_list_of_metrics[[:metrics, :passing_time_avg]],
              single_try_list_of_metrics[[:metrics, :passing_time_std]]
            )

          File.write!(
            Path.join(
              Path.join(output_directory_path, @plots_directory),
              Integer.to_string(i) <> "_" <> @plot_filename
            ),
            output
          )
        end)
      end
    end
  end

  defp change_metric_strings_into_atoms(metrics_string) do
    chosen_metrics =
      for statistic_name <- metrics_string |> String.split(",") do
        String.to_atom(statistic_name)
      end

    chosen_metrics |> Enum.filter(fn key -> key in @available_metrics end)
  end
end
