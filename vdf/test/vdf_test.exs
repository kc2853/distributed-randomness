defmodule VdfTest do
  use ExUnit.Case
  doctest Vdf

  test "setup" do
     pp = Vdf.setup(nil, 8, 20)
     IO.puts("N is #{pp.n}, T is #{pp.t}")
    #  IO.puts("#{inspect(pp.primes)}")
     assert pp.t == 20, "N mismatch"
  end

  test "eval and verify" do
    pp = Vdf.setup(nil, 8, 6)
    IO.puts("N is #{pp.n}, T is #{pp.t}")
   #  IO.puts("#{inspect(pp.primes)}")
   {h, pi} = Vdf.eval(pp, 5)
   IO.puts("h is #{h}, pi is #{pi}")
   res = Vdf.verify(pp, 5, h, pi)
   IO.puts("Result is #{res}")
   assert res == True, "Result verified"
 end

# test "With nodes for 1 round of randomness" do
#   base_config = Vdf.setup([:a, :b, :c], 8, 20) # Identify nodes by numbers rather than alphabet??
#   spawn(:a, fn -> Vdf.become_node(base_config) end)
#   spawn(:b, fn -> Vdf.become_node(base_config) end)
#   spawn(:c, fn -> Vdf.become_node(base_config) end)
#   caller = self()
# end

end
