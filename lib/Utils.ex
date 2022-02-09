defmodule Utils do
  def wait_for_complete(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _msg} ->
        IO.puts("Exit from #{inspect(pid)}")
    end
  end
end
