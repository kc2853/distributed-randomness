defmodule Vdf do
  defstruct(
    view: nil,
    primes: nil,
    lambda: nil, # no of bits
    n: nil,
    t: nil
  )


  def generate_primes(lambda) do
    prime_list = :primes.primes_upto(:maths.pow(2, lambda))
    # IO.puts("List of primes is #{inspect(prime_list)}")
    # make a map out of it
    Stream.with_index(prime_list) 
    |> Enum.reduce(%{}, fn({v,k}, acc)-> Map.put(acc, k, v) end)
    # IO.puts("List of primes is #{inspect(acc)}")
  end


  @spec setup(
          [atom()],
          non_neg_integer(),
          non_neg_integer()
        ) :: %Vdf{}
  def setup(view, lambda, time) do
    i = div(lambda, 2)
    # IO.puts("lambda is #{lambda}, i is #{i}")
    p = :primes.random_prime(:maths.pow(2, i - 1), :maths.pow(2, i) - 1)
    q = :primes.random_prime(:maths.pow(2, i - 1), :maths.pow(2, i) - 1)
    IO.puts("p = #{p} and q = #{q}")
    # Add checks for correctness of p,q later
    n = p * q

    prime_map = generate_primes(lambda)
    

    %Vdf{
      view: view,
      primes: prime_map,
      lambda: lambda, 
      n: n,
      t: time
    }
  end

  @spec eval( # This will not be a new process. The execution has to stop for this.
    %Vdf{},
    non_neg_integer() # g = H(x's)
  ) :: {non_neg_integer(), non_neg_integer(), non_neg_integer()} #(y/h, proof pi)
  def eval(pp, g) do 
    t = pp.t
    n = pp.n

    e = :maths.pow(2, t)
    IO.puts("e is #{e}")
    h = :binary.decode_unsigned(:crypto.mod_pow(g, e, n))

    # # Prover generates l which is a mapping of (G,g,h,t) to Primes(lambda)
    ms = map_size(pp.primes)


    # l = pp.primes[:maths.mod(g*h*t, ms)] # use an actual Hash function, Fiat Shamir
    # IO.puts("l is #{l}")
    h_in = [g, h, t]
    l = pp.primes[:maths.mod(:binary.decode_unsigned(:crypto.hash(:sha256, h_in)) ,ms)]
    IO.puts("l is #{inspect(l)}")
    # h_out = pp.primes[
    #         :crypto.hash(:sha256, h_in) 
    #         |> :binary.decode_unsigned 
    #         |> (fn v -> {v, ms} end).()
    #         |> :maths.mod
    # ]
    # IO.puts("h_out2 is #{inspect(h_out)}")
    # Construct proof
    q = div(e, l) 
    IO.puts("q is #{q}")
    #r = :maths.mod(e, l)
    pi = :binary.decode_unsigned(:crypto.mod_pow(g, q, n)) 

    {h, pi}

  end


  def is_element(x, n) do
    if x >= 0 and x < n do true else false end
  
  # verify_caller should know lambda, get pp(lambda), x = compute Hash(r_i's), and 
  end


  @spec verify(
    %Vdf{},
    non_neg_integer(),
    non_neg_integer(),
    non_neg_integer()
  ) :: boolean()
  def verify(pp, g, h, pi) do #g = x, h = y
    ms = map_size(pp.primes)
    # l = pp.primes[:maths.mod(g* h * pp.t, ms)]
    h_in = [g, h, pp.t]
    l = pp.primes[:maths.mod(:binary.decode_unsigned(:crypto.hash(:sha256, h_in)) ,ms)]
    IO.puts("h_out1 is #{inspect(l)}")
    IO.puts("Eval method")
    IO.puts("l is #{l}")
    # check that g, h ∈ G
    if is_element(g, pp.n) do
      if is_element(h, pp.n) do
        if is_element(pi, pp.n) do
          r = :binary.decode_unsigned(:crypto.mod_pow(2, pp.t, l))
          IO.puts("r is #{r}")
          y1 = :binary.decode_unsigned(:crypto.mod_pow(pi, l, pp.n))
          y2 = :binary.decode_unsigned(:crypto.mod_pow(g, r, pp.n))
          y = :maths.mod(y1*y2, pp.n)
          IO.puts("y is #{y}")
          if y == h do 
            IO.puts("y==h")
            True 
          else 
            IO.puts("y!=h")
            False 
          end
        else
          IO.puts("pi not in G")
          False
        end
      else
        IO.puts("h not in G")
        False
      end
    else
      IO.puts("g not in G")
      False
    end
  end

  def broadcast_to_others(state, message) do
    me = whoami()

    state.view
    |> Enum.filter(fn pid -> pid != me end)
    |> Enum.map(fn pid -> send(pid, message) end)
  end

  def become_node(state) do
    #1. M = %{} , Create a map to keep track of the nodes from which we have received the random values
    #2. generate a random number in the mod N group G, say r1
    #3. count = 1
    #4. Add (1: r1) to M
    #5. Broadcast r1 to all nodes
    #6. Start listening for ri's from other nodes
    #   node(state, M, count)

    #### Note: For each round of randomness, M and count would be re initialized

  end

  def node(state, mapping, count) do
    if count != length(state.view) do
      receive do
          {sender, random_i} ->  node(state, Map.put(mapping, sender, random_i), count + 1)
      end
    else
      # stop recursing
      # Find a way to combine the values in mapping. Need to make sure that all the nodes, if given the same r_i's get the 
      # same output. The order in which the r_is are received should not matter (maybe sort the map according to the keys??)
      # R = Combine(r_i's)
      # x = Hash (R) (does x need to be in the group G? Can R and x generation be combined?)
      # Evaluate the vdf ie 
      # {h, pi} = Vdf.eval(state, x) 
      # Wait for its complettion
      # result = verify(state, x, h, pi)
      # send {h, result} to the caller--- Need a way to capture the caller(test process's address, maybe 
      # create a Client mode like Raft to start things up??)

      #### Testing
      # tester->Client->Nodes for generation of random value
      # Nodes( output from majority/ or only one??)->Client->Tester

      # In the test function vdf_test.exs
      #1. Listen for message from Client ->{h, result}
      #2. If result == false, run the whole thing again!
      #   Else, return the value 

      #### Note: This tests for a single random value. If we want to generate R random values, might need to recurse
      # until count_random == R


    

    end  
  end

  end

