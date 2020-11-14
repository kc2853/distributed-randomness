defmodule VdfTest do
  use ExUnit.Case
  doctest Vdf
  import Emulation, only: [spawn: 2, send: 2]
  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]

  # test "setup" do
  #   caller = self()
  #   IO.puts("Caller pid is #{inspect(caller)}")
  #    pp = Vdf.setup(nil, 8, 20, caller)
  #    IO.puts("N is #{pp.n}, T is #{pp.t}")
  #   #  IO.puts("#{inspect(pp.primes)}")
  #    assert pp.t == 20, "N mismatch"
  # end

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


test "With nodes for 1 round of randomness" do
  Emulation.init()
  caller = self()

  nodes = [:a, :b, :c, :d]
  # Start the processes
  base_client = Vdf.Client.setup_client(caller, 1, nodes)
  IO.puts("Client Setup done")
  client = spawn(:client, fn -> Vdf.Client.become_client(base_client) end)


  base_config = Vdf.setup(nodes, 16, 200, :client) # Identify nodes by numbers rather than alphabet??
  IO.puts("Node setup done")
  spawn(:a, fn -> Vdf.become_node(base_config) end)
  spawn(:b, fn -> Vdf.become_node(base_config) end)
  spawn(:c, fn -> Vdf.become_node(base_config) end)
  spawn(:d, fn -> Vdf.become_node(base_config) end)

  # Start listenining for reply from Client (not the vdf nodes)
  receive do
    {rnum, res} -> IO.puts("In tester, Random number generated is #{inspect(rnum)} and status is #{res}")
  end
  
end

end
