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
    Stream.with_index(prime_list) 
    |> Enum.reduce(%{}, fn({v,k}, acc)-> Map.put(acc, k, v) end)
  end


  @spec setup_client(
          [atom()],
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          pid()
        ) :: %Vdf{}
  defp setup_client(view, lambda, time, count, test) do
    i = div(lambda, 2)
    p = :primes.random_prime(:maths.pow(2, i - 1), :maths.pow(2, i) - 1)
    q = :primes.random_prime(:maths.pow(2, i - 1), :maths.pow(2, i) - 1)
    # Add checks for correctness of p,q later
    if p == q do # p and q should be distinct primes
      setup_client(view, lambda, time, count, test)
    end
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
    h = :binary.decode_unsigned(:crypto.mod_pow(g, e, n))

    # # Prover generates l which is a mapping of (G,g,h,t) to Primes(lambda)
    ms = map_size(pp.primes)

    # l = pp.primes[:maths.mod(g*h*t, ms)] # use an actual Hash function, Fiat Shamir
    h_in = to_string_([g, h, t])
    l = pp.primes[:maths.mod(:binary.decode_unsigned(:crypto.hash(:sha256, h_in)) ,ms)]
    # Construct proof
    q = div(e, l) 
    pi = :binary.decode_unsigned(:crypto.mod_pow(g, q, n)) 
    {h, pi}
  end


  def is_element(x, n) do
    if x >= 0 and x < n do true else false end
  end

  @spec verify(
    %Vdf{},
    non_neg_integer(),
    non_neg_integer(),
    non_neg_integer()
  ) :: boolean()
  def verify(pp, g, h, pi) do 
    ms = map_size(pp.primes)
    h_in = to_string_([g, h, pp.t])
    l = pp.primes[:maths.mod(:binary.decode_unsigned(:crypto.hash(:sha256, h_in)) ,ms)]
    # check that g, h ∈ G
    if is_element(g, pp.n) do
      if is_element(h, pp.n) do
        if is_element(pi, pp.n) do
          r = :binary.decode_unsigned(:crypto.mod_pow(2, pp.t, l))
          y1 = :binary.decode_unsigned(:crypto.mod_pow(pi, l, pp.n))
          y2 = :binary.decode_unsigned(:crypto.mod_pow(g, r, pp.n))
          y = :maths.mod(y1*y2, pp.n)
          if y == h do 
            # IO.puts("y==h")
            true 
          else 
            # IO.puts("y!=h")
            false 
          end
        else
          # IO.puts("pi not in G")
          false
        end
      else
        # IO.puts("h not in G")
        false
      end
    else
      # IO.puts("g not in G")
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
    # IO.puts("Process #{inspect(whoami())} has started")
    client_addr = state.client
    send(client_addr, :ready)
     # wait till all processes are ready , and receive a go-ahead from client
     receive do
       {^client_addr, :ready_all} ->
        #  IO.puts("Node #{whoami()} Received go ahead from client")
      end

    get_random_round(state)
  end

  def get_random_round(state) do
    received_nos = %{}
    ri = :rnd.random(2, state.n - 1) 
    count = 1
    received_nos = Map.put(received_nos, whoami(), ri)
    broadcast_to_others(state, ri)
    node(state, received_nos, count)
  end

  def node(state, mapping, count) do
    if count != length(state.view) do
      receive do
          {sender, random_i} ->  
            # IO.puts("#{whoami()} received a random number #{random_i} from #{sender}. Count is now #{count + 1}")
            node(state, Map.put(mapping, sender, random_i), count + 1)
      end
    else
      r_out = to_string_(Map.values(mapping))
      g = :maths.mod(:binary.decode_unsigned(:crypto.hash(:sha256, r_out)) ,state.n) # g = H(x) \in G
      {h, pi} = eval(state, g)
      send(state.client, {g, h, pi})
      get_random_round(state)
    end  
  end


  def wait_until_ready(views, ok_count) do
    receive do 
        {sender, :ready} -> 
            ok_count = ok_count + 1
            if(ok_count == length(views)) do 
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

  # Wait till the client gets :ready message from all the nodes. Once done, broadcast :ready_all to all the nodes 
    # so that the nodes can proceed 
  def wait_node_setup(state, r_count, res) do 
    ok_count = 0
    status = wait_until_ready(state.view, ok_count)
    if status == :ready_all do
      broadcast_to_nodes(state, :ready_all)
      :ok
    else
      :notok
    end
  end

  # listens for random numbers generated by the nodes. r_count keeps track of the current round (max is count_r) and n_count keeps 
  # track of the number of replies received for each round (max is the total nodes present)
  def listen_res(state, r_count, n_count, res) do 
    receive do
      {sender, {g, h, pi}} -> 
        status = verify(state, g, h, pi)
        # IO.puts("In client receive, round is #{r_count}, h is #{h} and proof is #{pi}")
        if status == false do 
          listen_res(state, r_count, n_count, res) # keep listening for more replies
        else
          n_count = n_count + 1
          if n_count == length(state.view) do # Wait till you receive "valid" numbers from all the nodes 
            IO.puts("Round #{r_count}, the random number R_#{r_count} is #{h}")
            res = Map.put(res, r_count, h)
            r_count = r_count + 1
            if r_count == state.count_r do
              res
            else
              listen_res(state, r_count, 0, res)
            end
          else 
            listen_res(state, r_count, n_count, res)
          end
        end
    end
  end

  def become_client(view, lambda, time, count, test) do
    start = :os.system_time(:millisecond)

    # Client sets up the public parameter N
    state = setup_client(view, lambda, time, count, test)
    send(test, state)
    res = %{} # to store the random numbers generated
    r_count = 0
    status = wait_node_setup(state, r_count, res)
    # Client waits till all the count_r random numbers are generated
    if status == :ok do
      n_count = 0
      res = listen_res(state, r_count, n_count, res)
      finish = :os.system_time(:millisecond)
      t = finish - start
      send(state.tester, {res, t})
    end
  end

end

  