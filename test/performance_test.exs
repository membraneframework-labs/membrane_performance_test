defmodule Test.PerformanceTest do
  use ExUnit.Case

  @tag timeout: :infinity
  test "if membrane core is fast enough" do
    opts = %{
      mode: "push",
      n: 3,
      how_many_tries: 10,
      tick: 10_000,
      inital_generator_frequency: 5_000,
      should_adjust_generator_frequency: true,
      should_produce_plots: false,
      metrics: [:generator_frequency],
      reductions: 1_000,
      plots_path: "/project/results/plots"
    }

    [generator_frequency: frequency] = List.last(Mix.Tasks.PerformanceTest.launch_test(opts))
    opts = %{opts| inital_generator_frequency: frequency, should_adjust_generator_frequency: false, metrics: [:throughput], how_many_tries: 0}
    IO.inspect(Mix.Tasks.PerformanceTest.launch_test(opts))

  end
end
