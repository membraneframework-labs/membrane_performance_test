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

  def calculate do
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

    # a*n+b = r
    a = trunc((r2 - r1) / (@n2 - @n1))
    b = r2 - a * @n2
    {a, b, r1, r2}
  end

  def prepare_desired_function(how_many_reductions) do
    {_a, _b, r1, r2} = calculate()
    n_better = trunc((how_many_reductions - r2) / (r2 - r1) * (@n2 - @n1) + @n2)

    fn ->
      for _ <- 1..n_better do
        @function
      end
    end

  end
end
