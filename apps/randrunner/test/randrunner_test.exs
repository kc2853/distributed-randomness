defmodule RandrunnerTest do
  use ExUnit.Case
  doctest Randrunner

  import Emulation, only: [spawn: 2]
  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]

  @moduletag timeout: :infinity


test "1. VDF generates n random numbers" do
  Emulation.init()

  caller = self()
  nodes = [:a, :b, :c, :d, :e, :f, :g, :h, :i, :j] 
  lambda = 16 
  time = 200000
  rcount = 10 # number of random numbers to be generated
  nrout = 16 # each random number is of at most 2^16 (16 bits)
  replier = :a
  reliable = true

  base_params = Randrunner.Params.setup_params(nodes, lambda, time, nrout, rcount, replier, reliable) # returns a %Params{}

  base_client = Randrunner.Client.setup_client(base_params, caller) # returns a %Client{}
  spawn(:client, fn -> Randrunner.Client.become_client(base_client) end)

  ## spawn nodes with base_params
  spawn(:a, fn -> Randrunner.Node.setup_nodes(base_params, :client) end) 
  spawn(:b, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:c, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:d, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:e, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:f, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:g, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:h, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:i, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:j, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)

  receive do
    {res, t} -> 
      assert Enum.count(res) == rcount
      IO.puts("In Test, results received from client. The random numbers are #{inspect(res)}")
      IO.puts("Total time takes is #{t} ms")
  end

end

test "2. VDF generates n random numbers with trivial delay" do
  Emulation.init()
  Emulation.append_fuzzers([Fuzzers.delay(2)])

  caller = self()
  nodes = [:a, :b, :c, :d, :e, :f, :g, :h, :i, :j] 
  lambda = 16 
  time = 200000
  rcount = 20 # number of random numbers to be generated
  nrout = 16 # each random number is of at most 2^16 (16 bits)
  replier = :a
  reliable = false

  base_params = Randrunner.Params.setup_params(nodes, lambda, time, nrout, rcount, replier, reliable) # returns a %Params{}

  base_client = Randrunner.Client.setup_client(base_params, caller) # returns a %Client{}
  spawn(:client, fn -> Randrunner.Client.become_client(base_client) end)

  ## spawn nodes with base_params
  spawn(:a, fn -> Randrunner.Node.setup_nodes(base_params, :client) end) 
  spawn(:b, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:c, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:d, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:e, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:f, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:g, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:h, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:i, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:j, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)


  receive do
    {res, t} -> 
      assert Enum.count(res) == rcount
      IO.puts("In Test, results received from client. The random numbers are #{inspect(res)}")
      IO.puts("Total time takes is #{t} ms")
  end

end

test "3. VDF generates n random numbers with non trivial message delay and no adversaries, no broadcasting" do
  Emulation.init()
  Emulation.append_fuzzers([Fuzzers.delay(500)])

  caller = self()
  nodes = [:a, :b, :c, :d, :e, :f, :g, :h, :i, :j] 
  lambda = 16 
  time = 200000
  rcount = 20 # number of random numbers to be generated
  nrout = 16 # each random number is of at most 2^16 (16 bits)
  replier = :a
  reliable = false

  base_params = Randrunner.Params.setup_params(nodes, lambda, time, nrout, rcount, replier, reliable) # returns a %Params{}

  base_client = Randrunner.Client.setup_client(base_params, caller) # returns a %Client{}
  spawn(:client, fn -> Randrunner.Client.become_client(base_client) end)

  ## spawn nodes with base_params
  spawn(:a, fn -> Randrunner.Node.setup_nodes(base_params, :client) end) 
  spawn(:b, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:c, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:d, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:e, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:f, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:g, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:h, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:i, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)
  spawn(:j, fn -> Randrunner.Node.setup_nodes(base_params, :client) end)


  receive do
    {res, t} -> 
      assert Enum.count(res) == rcount
      IO.puts("In Test, results received from client. The random numbers are #{inspect(res)}")
      IO.puts("Total time takes is #{t} ms")
  end

end

test "4. VDF generates n random numbers with no message delay, adversarial nodes and no broadcasting" do
  Emulation.init()
  Emulation.append_fuzzers([Fuzzers.delay(2)])

  caller = self()
  nodes = [:a, :b, :c, :d, :e, :f, :g, :h, :i, :j] 
  lambda = 16 
  time = 200000
  rcount = 20 # number of random numbers to be generated
  nrout = 16 # each random number is of at most 2^16 (16 bits)
  replier = :a
  reliable = false
  adv = true


  base_params = Randrunner.Params.setup_params(nodes, lambda, time, nrout, rcount, replier, reliable) # returns a %Params{}
  adversarial_params = %{base_params | adversarial: adv}


  base_client = Randrunner.Client.setup_client(base_params, caller) # returns a %Client{}
  spawn(:client, fn -> Randrunner.Client.become_client(base_client) end)

  ## spawn nodes with base_params
  spawn(:a, fn -> Randrunner.Node.setup_nodes(adversarial_params, :client) end) 
  spawn(:b, fn -> Randrunner.Node.setup_nodes(adversarial_params, :client) end)
  spawn(:c, fn -> Randrunner.Node.setup_nodes(adversarial_params, :client) end)
  spawn(:d, fn -> Randrunner.Node.setup_nodes(adversarial_params, :client) end)
  spawn(:e, fn -> Randrunner.Node.setup_nodes(adversarial_params, :client) end)
  spawn(:f, fn -> Randrunner.Node.setup_nodes(adversarial_params, :client) end)
  spawn(:g, fn -> Randrunner.Node.setup_nodes(adversarial_params, :client) end)
  spawn(:h, fn -> Randrunner.Node.setup_nodes(adversarial_params, :client) end)
  spawn(:i, fn -> Randrunner.Node.setup_nodes(adversarial_params, :client) end)
  spawn(:j, fn -> Randrunner.Node.setup_nodes(adversarial_params, :client) end)


  receive do
    {res, t} -> 
      assert Enum.count(res) == rcount
      IO.puts("In Test, results received from client. The random numbers are #{inspect(res)}")
      IO.puts("Total time takes is #{t} ms")
  end

end

test "5. VDF generates n random numbers with non trivial message delay, adversarial nodes and no reliable broadcasting" do
  Emulation.init()
  Emulation.append_fuzzers([Fuzzers.delay(500)])

  caller = self()
  nodes = [:a, :b, :c, :d, :e, :f, :g, :h, :i, :j] 
  lambda = 16 
  time = 200000
  rcount = 20 # number of random numbers to be generated
  nrout = 16 # each random number is of at most 2^16 (16 bits)
  replier = :a
  reliable = false
  adv = true

  base_params = Randrunner.Params.setup_params(nodes, lambda, time, nrout, rcount, replier, reliable) # returns a %Params{}
  adversarial_params = %{base_params | adversarial: adv}

  base_client = Randrunner.Client.setup_client(base_params, caller) # returns a %Client{}
  spawn(:client, fn -> Randrunner.Client.become_client(base_client) end)

  ## spawn nodes with base_params
  spawn(:a, fn -> Randrunner.Node.setup_nodes(adversarial_params, :client) end) 
  spawn(:b, fn -> Randrunner.Node.setup_nodes(adversarial_params, :client) end)
  spawn(:c, fn -> Randrunner.Node.setup_nodes(adversarial_params, :client) end)
  spawn(:d, fn -> Randrunner.Node.setup_nodes(adversarial_params, :client) end)
  spawn(:e, fn -> Randrunner.Node.setup_nodes(adversarial_params, :client) end)
  spawn(:f, fn -> Randrunner.Node.setup_nodes(adversarial_params, :client) end)
  spawn(:g, fn -> Randrunner.Node.setup_nodes(adversarial_params, :client) end)
  spawn(:h, fn -> Randrunner.Node.setup_nodes(adversarial_params, :client) end)
  spawn(:i, fn -> Randrunner.Node.setup_nodes(adversarial_params, :client) end)
  spawn(:j, fn -> Randrunner.Node.setup_nodes(adversarial_params, :client) end)


  receive do
    {res, t} -> 
      assert Enum.count(res) == rcount
      IO.puts("In Test, results received from client. The random numbers are #{inspect(res)}")
      IO.puts("Total time takes is #{t} ms")
      
  end

end

end
