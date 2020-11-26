
defmodule Randrunner do

  def eval(pp_lr, g, pp) do # usage Randrunner.eval(state.pp[lr], xr, state.params)
    t = pp.t
    n = pp_lr

    e = :maths.pow(2, t)
    # IO.puts("Normal e is #{e}")
    h = :binary.decode_unsigned(:crypto.mod_pow(g, e, n))

    # # Prover generates l which is a mapping of (G,g,h,t) to Primes(lambda)
    ms = map_size(pp.primes)
    # IO.puts("ms is #{ms}")


    # l = pp.primes[:maths.mod(g*h*t, ms)] # use an actual Hash function, Fiat Shamir
    # IO.puts("l is #{l}")
    h_in = to_string_([g, h, t])
    l = pp.primes[:maths.mod(:binary.decode_unsigned(:crypto.hash(:sha256, h_in)) ,ms)]
    # IO.puts("l is #{inspect(l)}")
    # Construct proof
    q = div(e, l) 
    # IO.puts("q is #{q}")
    #r = :maths.mod(e, l)
    pi = :binary.decode_unsigned(:crypto.mod_pow(g, q, n)) 

    {h, pi}

  end

  def trapdoor_eval(pp_i, g, pp, pi, qi) do
    # IO.puts("Trapdoor eval")
    t = pp.t
    n = pp_i
    phi_n = (pi - 1) * (qi - 1)

    e = :maths.pow(2, t)
    e_td = :maths.mod(e, phi_n)
    # e = :maths.mod(:maths.pow(2, t), phi_n)
    # e = :binary.decode_unsigned(:crypto.mod_pow(2, t, phi_n))
    # IO.puts("trapdoor e is #{e}, e_td id #{e_td}")
    h = :binary.decode_unsigned(:crypto.mod_pow(g, e_td, n))

    # # Prover generates l which is a mapping of (G,g,h,t) to Primes(lambda)
    ms = map_size(pp.primes)
    # IO.puts("ms is #{ms}")

    # l = pp.primes[:maths.mod(g*h*t, ms)] # use an actual Hash function, Fiat Shamir
    # IO.puts("l is #{l}")
    h_in = to_string_([g, h, t])
    l = pp.primes[:maths.mod(:binary.decode_unsigned(:crypto.hash(:sha256, h_in)) ,ms)]
    # IO.puts("l is #{inspect(l)}")
    # Construct proof
    q = div(e, l) 
    # IO.puts("q is #{q}")
    #r = :maths.mod(e, l)
    pi = :binary.decode_unsigned(:crypto.mod_pow(g, q, n)) 

    {h, pi}


  end

  def is_element(x, n) do
    if x >= 0 and x < n do true else false end
  end

  defp to_string_(l) do
    l_str = l |> Enum.map_join("", fn el -> "#{el}" end)

    l_str
  end

  def verify(pp_lr, pp, g, h, pi) do #g = x, h = y, call verify(state.pp[lr], state.params, xr, y, pi)
    ms = map_size(pp.primes)
    # l = pp.primes[:maths.mod(g* h * pp.t, ms)]
    h_in = to_string_([g, h, pp.t])
    l = pp.primes[:maths.mod(:binary.decode_unsigned(:crypto.hash(:sha256, h_in)) ,ms)]
    # IO.puts("h_out1 is #{inspect(l)}")
    # IO.puts("l is #{l}")
    # check that g, h ∈ G
    if is_element(g, pp_lr) do
      if is_element(h, pp_lr) do
        if is_element(pi, pp_lr) do
          r = :binary.decode_unsigned(:crypto.mod_pow(2, pp.t, l))
          # IO.puts("r is #{r}")
          y1 = :binary.decode_unsigned(:crypto.mod_pow(pi, l, pp_lr))
          y2 = :binary.decode_unsigned(:crypto.mod_pow(g, r, pp_lr))
          y = :maths.mod(y1*y2, pp_lr)
          # IO.puts("y is #{y}")
          if y == h do 
            IO.puts("y == h")
            true 
          else 
            IO.puts("y != h")
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

end


defmodule Randrunner.Params do
  import Emulation, only: [send: 2, timer: 1, now: 0, whoami: 0]

  import Kernel,
  except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]
  
  alias __MODULE__
  
    defstruct(
    view: nil,
    primes: nil,
    lambda: nil, # number of bits
    t: nil,
    n_rbits: nil, # number of bits in the output random number
    n_r: nil, #(R_i = lr mod n_r) where n_r = 2^n_rbits
    count_r: nil # number of random numbers to be generated
  )

  def generate_primes(lambda) do
    prime_list = :primes.primes_upto(:maths.pow(2, lambda))
    # IO.puts("List of primes is #{inspect(prime_list)}")
    # make a map out of it
    Stream.with_index(prime_list) 
    |> Enum.reduce(%{}, fn({v,k}, acc)-> Map.put(acc, k, v) end)
  end

  def setup_params(view, lambda, time, nr, count) do # primes, 
    
    prime_map = generate_primes(lambda)
    r = :maths.pow(2, nr) # usually 2^256

    %Params{
      view: view,
      primes: prime_map,
      lambda: lambda, 
      t: time,
      n_rbits: nr,
      n_r: r,
      count_r: count
    }
  end
end


defmodule Randrunner.Node do
  import Emulation, only: [spawn: 2, send: 2, timer: 1, now: 0, whoami: 0]

  import Kernel,
  except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]
  
  alias __MODULE__
  
  defstruct(
    params: nil, # base_params
    p: nil,
    q: nil,
    n: nil,
    pp: nil, # public parameters of all the other nodes o form %{:node : n_i}
    r_0: nil,
    r_prev: nil,
    client: nil
  )

  def broadcast_to_others(state, message) do
    me = whoami()

    state.view
    |> Enum.filter(fn pid -> pid != me end)
    |> Enum.map(fn pid -> send(pid, message) end)
  end

  def setup_trapdoor(param) do
    lambda = param.lambda
    i = div(lambda, 2)
    IO.puts("lambda is #{lambda}, i is #{i}")
    p = :primes.random_prime(:maths.pow(2, i - 1), :maths.pow(2, i) - 1)
    q = :primes.random_prime(:maths.pow(2, i - 1), :maths.pow(2, i) - 1)
    # Add checks for correctness of p,q later
    n = p * q
    IO.puts("N is #{n}")
    {p, q, n}
  end

  def listen_pp(state, mapping, count) do
    if count != length(state.view) do
      receive do
          {sender, n_i} ->  
            # IO.puts("#{whoami()} received a random number #{n_i} from #{sender}. Count is now #{count + 1}")
            listen_pp(state, Map.put(mapping, sender, n_i), count + 1)
      end
    else
      mapping
    end
  end

  def setup_nodes(param, client_add) do # called in test script ONLY ONCE INITIALLY
    # setup p_i, q_i, n
    {p_i, q_i, n_i} = setup_trapdoor(param) # only the node executing this process knows about p_i, q_i, whereas n_i is made public

    
    
    # generate R_0_i
    r_0_i = :rnd.random(2, n_i - 1) ## random number in %N group
    # IO.puts("Random share of #{inspect(whoami())} is #{r_0_i} and client address is #{inspect(client_add)}")

    # Checkpoint 2 - send a reply to client that it is ready + its share for R_0_i. 
    send(client_add, {:ready, r_0_i})

    # Wait. When all the nodes are ready, will receive :ready_all + R_0 from client
    r_0 = receive do
            {sender, {:ready_all, r_0}} ->
            IO.puts("In node #{inspect(whoami())} all nodes setup. R_init is #{r_0}")
            r_0
          end

    # Checkpoint 1 - parameter exchange
    pp = %{}
    # add its own pp first
    count = 1
    pp = Map.put(pp, whoami(), n_i)
    broadcast_to_others(param, n_i)
    pp = listen_pp(param, pp, count) # listen and accumulate from all the other nodes
    # IO.puts("pp received at node #{inspect(whoami())} is #{inspect(pp)}")
   
    state = %Node{
      params: param,
      p: p_i,
      q: q_i,
      n: n_i,
      pp: pp,
      r_0: r_0,
      r_prev: r_0,
      client: client_add
    }
    # IO.puts("The node state is #{inspect(state)}")
    ####### Parameter setup done ###########

    rcount = 0 # at the end, param.count_r
    random_gen = %{}
    become_node(state, rcount, random_gen)
  end

  def derive_leader(state, rcount) do
    n = length(state.params.view)
    index = :maths.mod(state.r_prev, n)
    Enum.at(state.params.view, index)
  end


  def h_in(state, lr) do
    r_prev = state.r_prev
    n_lr = state.pp[lr]
    s_r_prev = "#{r_prev}"
    x = :maths.mod(:binary.decode_unsigned(:crypto.hash(:sha256, s_r_prev)) ,n_lr)
    # IO.puts("lr is #{lr}, n_lr is #{n_lr} and x is #{x}")
    x
  end

  def h_out(state, r) do
    s_r = "#{r}"
    n_r = state.params.n_r
    r_out = :maths.mod(:binary.decode_unsigned(:crypto.hash(:sha256, s_r)) ,n_r)
    r_out
  end


  def become_node(state, rcount, random_gen) do ## DONT FORGET TO SET r_prev every time a random number is generated
    if rcount < state.params.count_r do
      lr = derive_leader(state, rcount) # lr is an atom in {:a, :b, :c....}
      IO.puts("The leader for the round #{rcount} is #{inspect(lr)}")
      xr = h_in(state, lr)
      i = whoami()
      {y_r, pi_r} = if i == lr do 
                      # No verify() needed
                      # in this case, this node (i) is the leader of round r, so the trapdoor sk_i is used to quickly compute the VDF and broadcasted
                      {y_r, pi_r} = Randrunner.trapdoor_eval(state.pp[i], xr, state.params, state.p, state.q)
                      IO.puts(" trapdoor: In leader process #{lr} result is #{inspect(y_r)}, #{inspect(pi_r)}")
                      # add it to the list of numbers, increment rcount, change state.rprev
                      broadcast_to_others(state.params, {i, y_r, pi_r})
                      {y_r, pi_r}
                    else
                      # IO.puts("in process #{inspect(whoami())} pp_lr is #{state.pp[lr]}, x_r is #{xr} and T is #{state.params.t}")
                      # spawn a new process to evaluate the vdf
                      task = Task.async(fn -> Randrunner.eval(state.pp[lr], xr, state.params) end)  
                      # result = Task.await(task)
                      {y_r, pi_r} = listen_y(state, lr, xr)
                      {y_r, pi_r}                    
                    end
      IO.puts("{y_r, pi_r} at process #{whoami()} is #{y_r}, #{pi_r}")

      # compute and output Rr = Hout(yr)
      r_r = h_out(state, y_r)
      IO.puts("at process #{whoami()}, R_#{rcount} is #{r_r}")

      # add r_r to the map random_gen, reset state.r_prev , increment rcount and recurse
      become_node(%{state | r_prev: r_r}, rcount + 1, Map.put(random_gen, rcount, r_r))
    else
      IO.puts("All numbers generated, ranom_gen is #{inspect(random_gen)}")
      send(state.client, random_gen)
    end
  end

  def listen_y(state, lr, xr) do
     # in this process keep listening. Whichever produces the output first
    i = whoami()
    receive do
      {sender, {lr, y, pi}} ->
        IO.puts("trapdoor: In process #{whoami()}, received from trapdoor_eval(), result is #{inspect(lr)}, #{inspect(y)}, #{inspect(pi)}")
        if(Randrunner.verify(state.pp[lr], state.params, xr, y, pi) == true) do
          {y, pi}
        else
          IO.puts("trapdoor: In process #{whoami()}, Verify evaluated to false, keep listening")
          listen_y(state, lr, xr)
        end

      {_, {y, pi}} -> 
        IO.puts("task: In process #{whoami()}, received from eval(), result is #{inspect(y)}, #{inspect(pi)}")
        if(Randrunner.verify(state.pp[lr], state.params, xr, y, pi) == true) do
          {y, pi}
        else
          IO.puts("task: In process #{whoami()}, Verify evaluated to false, keep listening")
          listen_y(state, lr, xr)
        end
    end
  end

end


defmodule Randrunner.Client do
  import Emulation, only: [send: 2, timer: 1, now: 0, whoami: 0]

  import Kernel,
  except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]
  
  alias __MODULE__

  defstruct(
    params: nil, # base_params
    tester: nil
  )

  def setup_client(param, tid) do
    %Client{
      params: param,
      tester: tid
    }
  end

  def broadcast_to_nodes(state, message) do  
    state.view
    |> Enum.map(fn pid -> send(pid, message) end)
  end

  defp to_string_(l) do
    l_str = l |> Enum.map_join("", fn el -> "#{el}" end)

    l_str
  end

  def wait_until_ready(client, ok_count, received_nos) do
    views = client.params.view
    IO.puts("Client started listening at #{inspect(whoami())}")
    receive do 
      {sender, {:ready, r_0_i}} -> 
        ok_count = ok_count + 1

        # add it to the map received_nos
        received_nos = Map.put(received_nos, sender, r_0_i)

        # IO.puts("Received :ready from #{sender} with share #{r_0_i} and ok_count is #{ok_count}")
        
        # Once you've received all the shares, combine them, broadcast to all the nodes, then return :ready_all
        if(ok_count == length(views)) do 
          r_out = to_string_(Map.values(received_nos))
          # IO.puts("The concatenated string of lists is #{inspect(r_out)} in #{whoami()}")
          r_0 = :maths.mod(:binary.decode_unsigned(:crypto.hash(:sha256, r_out)) ,client.params.n_r)

          IO.puts("Have received from all the nodes, the initial random number R_init is #{r_0}(max value is #{client.params.n_r})")
          {:ready_all, r_0}

        else
          wait_until_ready(client, ok_count, received_nos)
        end
    end
  end

  def wait_node_setup(client) do 
    # Wait till the client gets :ready message from all the nodes. Once done, broadcast :ready_all to all the nodes 
    # so that the nodes can proceed 
    ok_count = 0
    received_nos = %{} # to generate R_0
    {status, r_0} = wait_until_ready(client, ok_count, received_nos)
    if status == :ready_all do
      broadcast_to_nodes(client.params, {:ready_all, r_0})
      {:ok, r_0}
    else
      {:notok, r_0}
    end
  end


  def become_client(client) do
    res = %{}
    # Generate an initial random seed r_0 (same number of bits as R_1, R_2 etc)
    {status, r_0} = wait_node_setup(client) # wait for all the nodes to be setup 
    ## r_0 is used to find the 1st leader and also as input(H(x)) to the vdf
    r_count = 0
    if status == :ok do
      # res = listen_res(client, r_count, res) ### Make the nodes return {round_id = r_count, random number} instead of just the random number
      # Listen for results
      res = receive do
              {sender, res} -> 
                IO.puts("Received the result in Client from #{sender}")
                res
            end
      send(client.tester, res)
    end
  end



end
