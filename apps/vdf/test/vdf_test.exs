defmodule VdfTest do
  use ExUnit.Case
  doctest Vdf
  import Emulation, only: [spawn: 2, send: 2]
  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]

  @moduletag timeout: :infinity

#   test "setup" do
#     caller = self()
#     IO.puts("Caller pid is #{inspect(caller)}")
#      pp = Vdf.setup(nil, 8, 20, caller)
#      IO.puts("N is #{pp.n}, T is #{pp.t}")
#     #  IO.puts("#{inspect(pp.primes)}")
#      assert pp.t == 20, "N mismatch"
#   end

#   test "eval and verify" do
#     pp = Vdf.setup(nil, 8, 6)
#     IO.puts("N is #{pp.n}, T is #{pp.t}")
#    #  IO.puts("#{inspect(pp.primes)}")
#    {h, pi} = Vdf.eval(pp, 5)
#    IO.puts("h is #{h}, pi is #{pi}")
#    res = Vdf.verify(pp, 5, h, pi)
#    IO.puts("Result is #{res}")
#    assert res == True, "Result verified"
#  end


test "With nodes for N round of randomness" do
  Emulation.init()
  caller = self()

  nodes = [:a, :b, :c, :d]
  lambda = 16
  time = 4000
  rcount = 7
  client = spawn(:client, fn -> Vdf.become_client(nodes, lambda, time, rcount, caller) end)

  base_config = receive do
            state -> 
              state
              # IO.puts("State received #{inspect(state)}")
          end
  IO.puts("Base State is #{inspect(base_config)}")
  # base_config = Vdf.setup_client(nodes, lambda, time, caller) # Identify nodes by numbers rather than alphabet??
  # IO.puts("Config is #{inspect(base_config)}")
  IO.puts("Public setup done")
  spawn(:a, fn -> Vdf.become_node(base_config) end)
  spawn(:b, fn -> Vdf.become_node(base_config) end)
  spawn(:c, fn -> Vdf.become_node(base_config) end)
  spawn(:d, fn -> Vdf.become_node(base_config) end)

  # # Start listenining for reply from Client (not the vdf nodes)
  receive do
    # {rnum, res} -> IO.puts("In tester, Random number generated is #{inspect(rnum)} and status is #{res}")
    res -> IO.puts("In tester, Random number generated is #{inspect(res)}")
  end
  
end

end
