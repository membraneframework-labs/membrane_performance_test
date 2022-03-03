defmodule Test.PerformanceTest do
  use ExUnit.Case

  @tag timeout: :infinity
  test "if membrane core is fast enough" do
    average_push_throughput = get_average_throughput("push", 0)
    average_pull_throughput = get_average_throughput("pull", 0)
    average_autodemand_throughput = get_average_throughput("autodemand", 0)

    IO.puts(
      "PUSH: #{average_push_throughput} PULL: #{average_pull_throughput} AUTODEMAND: #{average_autodemand_throughput}"
    )
  end

  defp get_average_throughput(mode, how_many_tries) do
    opts = %{
      mode: mode,
      number_of_elements: 10,
      how_many_tries: 10,
      tick: 10_000,
      inital_generator_frequency: 50_000,
      should_adjust_generator_frequency: true,
      should_produce_plots: false,
      chosen_metrics: [:generator_frequency],
      reductions: 0
    }

    [generator_frequency: frequency] = List.last(Mix.Tasks.PerformanceTest.launch_test(opts))

    opts = %{
      opts
      | inital_generator_frequency: frequency,
        should_adjust_generator_frequency: false,
        chosen_metrics: [:throughput],
        how_many_tries: how_many_tries
    }

    result = Mix.Tasks.PerformanceTest.launch_test(opts)

    average_throughput =
      (result |> Enum.map(fn metrics_list -> metrics_list[:throughput] end) |> Enum.sum()) /
        length(result)

    average_throughput
  end
end