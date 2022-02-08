defmodule Mix.Tasks.PerformanceTest do

  use Mix.Task
  @initial_lower_bound 0
  @initial_upper_bound 100_000
  @numerator_of_probing_factor 1
  @denominator_of_probing_factor 100
  @syntax_error_message "Wrong syntax! Try: mix performance_test --mode <push|pull|autodemand> --n <number of elements> --howManyTries <how many tries> --tick <single try length [ms]> [output directory]"
  @keywords_list [mode: :string, n: :integer, howManyTries: :integer, tick: :integer]
  def run(args) do
    {options, arguments, errors} = OptionParser.parse(args, strict: @keywords_list)
    if errors != [] or length(arguments) != 1 or Enum.any?(@keywords_list, fn {key, _value}-> not Keyword.has_key?(options, key) end ) do
      IO.puts(@syntax_error_message)
    else
      mode = Keyword.get(options, :mode)
      n = Keyword.get(options, :n)
      how_many_tries = Keyword.get(options, :how_many_tries)
      tick = Keyword.get(options, :tick)
      [output_directory_path] = arguments
      pid = case mode do
        "push" -> {:ok, pid} = Pipeline.start_link(%{
                    n: n,
                    source: %PushMode.Elements.Source{initial_lower_bound: @initial_lower_bound, initial_upper_bound: @initial_upper_bound},
                    filter: %PushMode.Elements.Filter{id: -1},
                    sink: %PushMode.Elements.Sink{tick: tick, how_many_tries: how_many_tries, numerator_of_probing_factor: @numerator_of_probing_factor, denominator_of_probing_factor: @denominator_of_probing_factor, should_produce_plots?: false, output_directory: output_directory_path}
                  })
                  pid
        "pull" -> {:ok, pid} = Pipeline.start_link(%{
                    n: n,
                    filter: %PullMode.Elements.Filter{id: -1},
                    source: PullMode.Elements.Source,
                    sink: %PullMode.Elements.Sink{tick: tick, how_many_tries: how_many_tries, output_directory: output_directory_path}
                  })
                  pid
        "autodemand" -> {:ok, pid} = Pipeline.start_link(%{
                  n: n,
                  filter: %AutoDemand.Elements.Filter{id: -1},
                  source: AutoDemand.Elements.Source,
                  sink: %AutoDemand.Elements.Sink{tick: tick, how_many_tries: how_many_tries, output_directory: output_directory_path}
                })
                pid
        value -> IO.puts("Unknown mode: #{value}")
            IO.puts(@syntax_error_message)
      end

      Pipeline.play(pid)
      Utils.wait_for_complete(pid)
  end

  end
end
