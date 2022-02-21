defmodule Mix.Tasks.PerformanceTest do
  use Mix.Task
  @numerator_of_probing_factor 1
  @denominator_of_probing_factor 100
  @syntax_error_message "Wrong syntax! Try: mix performance_test --mode <push|pull|autodemand> --n <number of elements> --howManyTries <how many tries> --tick <single try length [ms]> --initialLowerBound <> --initialUpperBound <> [output directory]"
  @strict_keywords_list [mode: :string, n: :integer, howManyTries: :integer, tick: :integer, initalGeneratorFrequency: :integer]
  @optional_keywords_list [shouldAdjustGeneratorFrequency: :boolean, shouldProducePlots: :boolean, shouldProvideStatisticsHeader: :boolean ]
  @statistics [:tick, :throughput, :avg, :std, :tries_counter, :generator_frequency]
  def run(args) do
    {options, arguments, errors} = OptionParser.parse(args, strict: @strict_keywords_list++@optional_keywords_list)

    if errors != [] or length(arguments) != 1 or
         Enum.any?(@strict_keywords_list, fn {key, _value} -> not Keyword.has_key?(options, key) end) do
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
      should_provide_statistics_header = Keyword.get(options, :shouldProvideStatisticsHeader)
      initial_lower_bound = 0
      initial_upper_bound = inital_generator_frequency*2
      [output_directory_path] = arguments

      case mode do
        "pull" ->
          options = %{
            n: n,
            source: nil,
            filter: %PullMode.Elements.Filter{id: -1},
            sink: %PullMode.Elements.Sink{
              tick: tick,
              how_many_tries: how_many_tries,
              numerator_of_probing_factor: @numerator_of_probing_factor,
              denominator_of_probing_factor: @denominator_of_probing_factor,
              should_produce_plots?: should_produce_plots,
              output_directory: output_directory_path,
              supervisor_pid: self(),
              statistics: @statistics,
              provide_statistics_header?: should_provide_statistics_header
            }
          }

          if should_adjust_generator_frequency do
            options = %{options|
              source: %PullMode.Elements.Source{
                initial_lower_bound: initial_lower_bound,
                initial_upper_bound: initial_upper_bound
              }
            }
            {:ok, pid} = Pipeline.start_link(options)
            Pipeline.play(pid)
            frequency = receive do
              {:generator_frequency_found, generator_frequency} ->
                generator_frequency
            end
            IO.puts(frequency)
          else
            options = %{options|
              source: %PullMode.Elements.Source{
                initial_lower_bound: inital_generator_frequency,
                initial_upper_bound: inital_generator_frequency
              }
            }
            {:ok, pid} = Pipeline.start_link(options)
            Pipeline.play(pid)
            Utils.wait_for_complete(pid)
          end
        "push" ->
          nil
        "autodemand" ->
          nil
        value ->
          IO.puts("Unknown mode: #{value}")
          IO.puts(@syntax_error_message)
        end

    end
  end

end
