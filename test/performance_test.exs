defmodule Test.PerformanceTest do
  use ExUnit.Case

  test "if membrane core is fast enough" do
    args = [n: 10]
    Mix.Tasks.PerformanceTest.run(args)

  end
end
