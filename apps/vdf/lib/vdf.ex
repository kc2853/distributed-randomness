defmodule Vdf do
  import Emulation, only: [send: 2, timer: 1, now: 0, whoami: 0]

  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]
  


  defstruct(
    view: nil,
    primes: nil,
    lambda: nil, # no of bits
    n: nil,
    t: nil,
    count_r: nil,
    client: nil,
    tester: nil
  )


  def generate_primes(lambda) do
    prime_list = :primes.primes_upto(:maths.pow(2, lambda))
    # IO.puts("List of primes is #{inspect(prime_list)}")
    # make a map out of it
    Stream.with_index(prime_list) 
    |> Enum.reduce(%{}, fn({v,k}, acc)-> Map.put(acc, k, v) end)
    # IO.puts("List of primes is #{inspect(acc)}")
  end


  @spec setup_client(
          [atom()],
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          pid()
        ) :: %Vdf{}
  def setup_client(view, lambda, time, count, test) do
    i = div(lambda, 2)
    # IO.puts("lambda is #{lambda}, i is #{i}")
    p = :primes.random_prime(:maths.pow(2, i - 1), :maths.pow(2, i) - 1)
    q = :primes.random_prime(:maths.pow(2, i - 1), :maths.pow(2, i) - 1)
    # Add checks for correctness of p,q later
    n = p * q
    IO.puts("N is #{n}")
    prime_map = generate_primes(lambda)
    

    %Vdf{
      view: view,
      primes: prime_map,
      lambda: lambda, 
      n: n,
      t: time,
      count_r: count,
      client: whoami(),
      tester: test
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
    # IO.puts("e is #{e}")
    h = :binary.decode_unsigned(:crypto.mod_pow(g, e, n))

    # # Prover generates l which is a mapping of (G,g,h,t) to Primes(lambda)
    ms = map_size(pp.primes)


    # l = pp.primes[:maths.mod(g*h*t, ms)] # use an actual Hash function, Fiat Shamir
    # IO.puts("l is #{l}")
    h_in = to_string_([g, h, t])
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
    h_in = to_string_([g, h, pp.t])
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
            true 
          else 
            IO.puts("y!=h")
            false 
          end
        else
          IO.puts("pi not in G")
          false
        end
      else
        IO.puts("h not in G")
        false
      end
    else
      IO.puts("g not in G")
      false
    end
  end

  def broadcast_to_others(state, message) do
    me = whoami()

    state.view
    |> Enum.filter(fn pid -> pid != me end)
    |> Enum.map(fn pid -> send(pid, message) end)
  end

  defp to_string_(l) do
    l_str = l |> Enum.map_join("", fn el -> "#{el}" end)

    l_str
  end


  def become_node(state) do
    IO.puts("Process #{inspect(whoami())} has started")
    client_addr = state.client
    send(client_addr, :ready)
     # wait till all processes are ready , and receive a go-ahead from client
     receive do
       {^client_addr, :ready_all} ->
         IO.puts("Node #{whoami()} Received go ahead from client")
      end

    IO.puts("All the nodes are ready")
    get_random_round(state)
  end

  def get_random_round(state) do
    received_nos = %{}
    ri = :rnd.random(2, state.n - 1) ## random number in %N group
    count = 1
    received_nos = Map.put(received_nos, whoami(), ri)
    IO.puts("The map at #{whoami()} is #{inspect(received_nos)}")
    broadcast_to_others(state, ri)
    node(state, received_nos, count)
    #### Note: For each round of randomness, M and count would be re initialized
  end

  def node(state, mapping, count) do
    if count != length(state.view) do
      receive do
          {sender, random_i} ->  
            IO.puts("#{whoami()} received a random number #{random_i} from #{sender}. Count is now #{count + 1}")
            node(state, Map.put(mapping, sender, random_i), count + 1)
      end
    else
      IO.puts("The final mapping is #{inspect(mapping)}")
      # r_out = generate_list(state, mapping)
      r_out = to_string_(Map.values(mapping))
      # r_out_s = to_string_(r_out)
      IO.puts("The list is #{inspect(r_out)} in #{whoami()}")
      g = :maths.mod(:binary.decode_unsigned(:crypto.hash(:sha256, r_out)) ,state.n) # g = H(x) \in G
      IO.puts("g is #{inspect(g)}")
      {h, pi} = eval(state, g)
      # IO.puts("h is #{h} and pi is #{pi}")
      # result = verify(state, g, h, pi)
      # IO.puts("result is #{result}")
      send(state.client, {g, h, pi})
      get_random_round(state)
    end  
  end


  def wait_until_ready(views, ok_count) do
    receive do 
        {sender, :ready} -> 
            ok_count = ok_count + 1
            IO.puts("Received :ready from #{sender} and ok_count is #{ok_count}")
            if(ok_count == length(views)) do 
              IO.puts("Have received from all the nodes")
              :ready_all
            else
              wait_until_ready(views, ok_count)
            end
    end
  end

  def broadcast_to_nodes(state, message) do  
    state.view
    |> Enum.map(fn pid -> send(pid, message) end)
  end

  def wait_node_setup(state, r_count, res) do 
    # Wait till the client gets :ready message from all the nodes. Once done, broadcast :ready_all to all the nodes 
    # so that the nodes can proceed 
    ok_count = 0
    status = wait_until_ready(state.view, ok_count)
    if status == :ready_all do
      broadcast_to_nodes(state, :ready_all)
      :ok
    else
      :notok
    end
  end


  def listen_res(state, r_count, n_count, res) do 
    receive do
      {sender, {g, h, pi}} -> 
        IO.puts("g is #{g}, h is #{h} and pi is #{pi}")
        status = verify(state, g, h, pi)
        IO.puts("result is #{status}")
        IO.puts("In client receive, round is #{r_count}, h is #{h} and proof is #{pi}")
        if status == false do 
          listen_res(state, r_count, n_count, res) #keep listening for more replies
        else
          n_count = n_count + 1
          if n_count == length(state.view) do # Wait till you receive "valid" numbers from all the nodes (alt. wait till you receive from majority)
            res = Map.put(res, r_count, h)
            r_count = r_count + 1
            if r_count == state.count_r do
              # return the result
              res
            else
              # reset n_count for the next round
              listen_res(state, r_count, 0, res)
            end
          else # havent received entries from all the nodes yet for round r_count
            listen_res(state, r_count, n_count, res)
          end
        end
    end
  end


  def become_client(view, lambda, time, count, test) do
    state = setup_client(view, lambda, time, count, test)
    send(test, state)
    res = %{} #store the random numbers generated
    r_count = 0
    status = wait_node_setup(state, r_count, res)
    if status == :ok do
      n_count = 0
      res = listen_res(state, r_count, n_count, res)
      send(state.tester, res)
    end
  end

end

  