defmodule VdfTest do
  use ExUnit.Case
  doctest Vdf
  import Emulation, only: [spawn: 2, send: 2]
  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]

  @moduletag timeout: :infinity

test "Generate N random numbers with trivial delay" do
  Emulation.init()
  Emulation.append_fuzzers([Fuzzers.delay(2)])
  caller = self()

  nodes = [:a, :b, :c, :d, :e, :f, :g, :h, :i, :j]
  lambda = 16
  time = 200000
  rcount = 20
  
  client = spawn(:client, fn -> Vdf.become_client(nodes, lambda, time, rcount, caller) end)

  base_config = receive do
            state -> 
              state
          end
  IO.puts("Public parameter setup done")
  spawn(:a, fn -> Vdf.become_node(base_config) end)
  spawn(:b, fn -> Vdf.become_node(base_config) end)
  spawn(:c, fn -> Vdf.become_node(base_config) end)
  spawn(:d, fn -> Vdf.become_node(base_config) end)
  spawn(:e, fn -> Vdf.become_node(base_config) end)
  spawn(:f, fn -> Vdf.become_node(base_config) end)
  spawn(:g, fn -> Vdf.become_node(base_config) end)
  spawn(:h, fn -> Vdf.become_node(base_config) end)
  spawn(:i, fn -> Vdf.become_node(base_config) end)
  spawn(:j, fn -> Vdf.become_node(base_config) end)

  # # Start listenining for reply from Client (not the vdf nodes)
  receive do
    {res, t} -> 
      assert Enum.count(res) == rcount
      IO.puts("In Test, results received from client. The random numbers are #{inspect(res)}")
      IO.puts("Total time takes is #{t} ms")
  end
  
end

test "Generate N random numbers with non-trivial delay" do
  Emulation.init()
  Emulation.append_fuzzers([Fuzzers.delay(500)])
  caller = self()

  nodes = [:a, :b, :c, :d, :e, :f, :g, :h, :i, :j]
  lambda = 16
  time = 200000
  rcount = 20
  client = spawn(:client, fn -> Vdf.become_client(nodes, lambda, time, rcount, caller) end)

  base_config = receive do
            state -> 
              state
          end
  IO.puts("Public parameter setup done")
  spawn(:a, fn -> Vdf.become_node(base_config) end)
  spawn(:b, fn -> Vdf.become_node(base_config) end)
  spawn(:c, fn -> Vdf.become_node(base_config) end)
  spawn(:d, fn -> Vdf.become_node(base_config) end)
  spawn(:e, fn -> Vdf.become_node(base_config) end)
  spawn(:f, fn -> Vdf.become_node(base_config) end)
  spawn(:g, fn -> Vdf.become_node(base_config) end)
  spawn(:h, fn -> Vdf.become_node(base_config) end)
  spawn(:i, fn -> Vdf.become_node(base_config) end)
  spawn(:j, fn -> Vdf.become_node(base_config) end)

  # # Start listenining for reply from Client (not the vdf nodes)
  receive do
    {res, t} -> 
      assert Enum.count(res) == rcount
      IO.puts("In Test, results received from client. The random numbers are #{inspect(res)}")
      IO.puts("Total time takes is #{t} ms")
  end
  
end

end
