defmodule RandrunnerTest do
  use ExUnit.Case
  doctest Randrunner

  import Emulation, only: [spawn: 2, send: 2]
  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]

  @moduletag timeout: :infinity

test "With nodes for N round of randomness" do
  Emulation.init()

  caller = self()
  nodes = [:a, :b, :c, :d, :e, :f, :g] ###use Enum.at(nodes, 0) to index it
  lambda = 16
  time = 40
  rcount = 7 # number of random numbers to be generated
  nrout = 16 # each random number is of at most 2^16 (16 bits)

  base_params = Randrunner.Params.setup_params(nodes, lambda, time, nrout, rcount) # returns a %Params{}
  # IO.puts("base parameters are #{inspect(base_params)}")

  base_client = Randrunner.Client.setup_client(base_params, caller) # returns a %Client{}
  ## spawn a become_client process which takes in base_client as input parameter
  spawn(:client, fn -> Randrunner.Client.become_client(base_client) end)

  ## spawn nodes with base_params
  spawn(:a, fn -> Randrunner.Node.setup_nodes(base_params, :client) end) # Note: client(instead of :client) does not work
  spawn(:b, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:c, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:d, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:e, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:f, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:g, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)


  receive do
    res -> 
      IO.puts("In Test, results received from client!. The random numbers are #{inspect(res)}")
  end

  
  
end


  
end
