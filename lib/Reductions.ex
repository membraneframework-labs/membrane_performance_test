defmodule Reductions do
  @function :erlang.date()
  @n1 1_00
  @n2 1_000_000
  def setup_process(n) do
    parent = self()

    spawn(fn ->
      for _ <- 1..n do
        @function
      end

      send(parent, :erlang.process_info(self())[:reductions])
    end)
  end

  defp calculate do
    setup_process(@n1)

    r1 =
      receive do
        value -> value
      end

    setup_process(@n2)

    r2 =
      receive do
        value -> value
      end

    {r1, r2}
  end

  def prepare_desired_function(how_many_reductions) do
    {r1, r2} = calculate()
    n = trunc((how_many_reductions - r2) / (r2 - r1) * (@n2 - @n1) + @n2)

    fn ->
      for _ <- 1..n do
        @function
      end
    end
  end
end
