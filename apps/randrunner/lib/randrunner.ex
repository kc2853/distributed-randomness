
defmodule Randrunner do
  import Emulation, only: [send: 2, timer: 1, now: 0, whoami: 0]

  import Kernel,
  except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]

  def eval(pp_lr, g, pp) do 
    start = :os.system_time(:millisecond)
    t = pp.t
    n = pp_lr

    e = :maths.pow(2, t)
    h = :binary.decode_unsigned(:crypto.mod_pow(g, e, n))

    # Prover generates l which is a mapping of (G,g,h,t) to Primes(lambda)
    ms = map_size(pp.primes)
    h_in = to_string_([g, h, t])
    l = pp.primes[:maths.mod(:binary.decode_unsigned(:crypto.hash(:sha256, h_in)) ,ms)]
    
    # Construct proof
    q = div(e, l) 
    # r = :binary.decode_unsigned(:crypto.mod_pow(2, t, l))
    # q = div((:maths.pow(2,t) - r), l)

    pi = :binary.decode_unsigned(:crypto.mod_pow(g, q, n)) 
    finish = :os.system_time(:millisecond)
    # IO.puts("eval() time is #{finish - start} ms")
    {h, pi}
  end

  def trapdoor_eval(pp_i, g, pp, pi, qi) do
    start = :os.system_time(:millisecond)


    t = pp.t
    n = pp_i
    phi_n = (pi - 1) * (qi - 1)
    e = :binary.decode_unsigned(:crypto.mod_pow(2, t, phi_n))
    h = :binary.decode_unsigned(:crypto.mod_pow(g, e, n))

    ## Prover generates l which is a mapping of (G,g,h,t) to Primes(lambda)
    ms = map_size(pp.primes)
    h_in = to_string_([g, h, t])
    l = pp.primes[:maths.mod(:binary.decode_unsigned(:crypto.hash(:sha256, h_in)) ,ms)]

    # Construct proof
    # r = :binary.decode_unsigned(:crypto.mod_pow(2, t, l))
    # q = :maths.mod((:maths.pow(2,t) - r) * :maths.mod_inv(l, phi_n), phi_n)
    q = :maths.mod(div(:maths.pow(2,t), l), phi_n)

    pi = :binary.decode_unsigned(:crypto.mod_pow(g, q, n))
    
    finish = :os.system_time(:millisecond)
    # IO.puts("Trapdoor_eval() time is #{finish - start} ms")
    {h, pi}
  end

  def is_element(x, n) do
    if x >= 0 and x < n do true else false end
  end

  defp to_string_(l) do
    l_str = l |> Enum.map_join("", fn el -> "#{el}" end)
    l_str
  end

  def verify(pp_lr, pp, g, h, pi) do 
    ms = map_size(pp.primes)
    h_in = to_string_([g, h, pp.t])
    l = pp.primes[:maths.mod(:binary.decode_unsigned(:crypto.hash(:sha256, h_in)) ,ms)]
    # check that g, h ∈ G
    if is_element(g, pp_lr) do
      if is_element(h, pp_lr) do
        if is_element(pi, pp_lr) do
          r = :binary.decode_unsigned(:crypto.mod_pow(2, pp.t, l))
          y = :maths.mod(:maths.pow(pi, l) * :binary.decode_unsigned(:crypto.mod_pow(g, r, pp_lr)), pp_lr)
          if y == h do 
            # IO.puts("y == h")
            true 
          else 
            # IO.puts("y != h y is #{y} and h is #{h} In Verify() of #{whoami()}, l is #{l} r is #{r}")
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
end


defmodule Randrunner.Params do
  import Emulation, only: [send: 2, timer: 1, now: 0, whoami: 0]

  import Kernel,
  except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]
  
  alias __MODULE__
  
    defstruct(
    view: nil,
    primes: nil,
    lambda: nil, # number of bits in the n
    t: nil,
    n_rbits: nil, # maximum number of bits in the output random number
    n_r: nil, # (R_i = lr mod n_r) where n_r = 2^n_rbits
    count_r: nil, # number of random numbers to be generated
    replier: nil, # for demonstration, set to :a
    adversarial: nil, 
    reliable: nil # whether to enable reliable broadcasting or not
  )

  # Used to generate l, which is used for non interactive proof generation
  def generate_primes(lambda) do
    prime_list = :primes.primes_upto(:maths.pow(2, lambda))
    Stream.with_index(prime_list) 
    |> Enum.reduce(%{}, fn({v,k}, acc)-> Map.put(acc, k, v) end)
  end

  def setup_params(view, lambda, time, nr, count, rep, rel) do 
    prime_map = generate_primes(lambda)
    r = :maths.pow(2, nr) # usually 2^256

    %Params{
      view: view,
      primes: prime_map,
      lambda: lambda, 
      t: time,
      n_rbits: nr,
      n_r: r,
      count_r: count,
      replier: rep,
      adversarial: false,
      reliable: rel
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
    p: nil, # (p,q) form the secret key
    q: nil,
    n: nil, # n = p * q, where p,q are distinct primes
    pp: nil, # map tp store the public parameters of all nodes of form %{:node_id : n_i}
    r_0: nil, # Initial random number 
    r_prev: nil, # Random number generated in the previous round, used to decide leader and to generate x
    client: nil # Client address
  )

### START OF HELPERS ####

  def broadcast_to_others(state, message) do
    me = whoami()
    state.view
    |> Enum.filter(fn pid -> pid != me end)
    |> Enum.map(fn pid -> send(pid, message) end)
  end

  def setup_trapdoor(param) do
    lambda = param.lambda
    i = div(lambda, 2)
    p = :primes.random_prime(:maths.pow(2, i - 1), :maths.pow(2, i) - 1)
    q = :primes.random_prime(:maths.pow(2, i - 1), :maths.pow(2, i) - 1)
    if p == q do # p and q should be distinct primes
      setup_trapdoor(param)
    else
      n = p * q
      {p, q, n}
    end
  end

  def listen_pp(state, mapping, count_pp) do
    if count_pp != length(state.view) do
      receive do
          {sender, n_i} ->  
            count_pp = count_pp + 1
            listen_pp(state, Map.put(mapping, sender, n_i), count_pp)
      end
    else
      mapping
    end
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
    x
  end

  def h_out(state, r) do
    s_r = "#{r}"
    n_r = state.params.n_r
    r_out = :maths.mod(:binary.decode_unsigned(:crypto.hash(:sha256, s_r)) ,n_r)
    r_out
  end

  def generate_trapdoor(pp_lr, xr, params, p, q, rcount) do
    {y, pi} = Randrunner.trapdoor_eval(pp_lr, xr, params, p, q)
    if Randrunner.verify(pp_lr, params, xr, y, pi) == false do
      IO.puts("Generate trapdoor failed in #{whoami()} for round #{rcount}!!")
      generate_trapdoor(pp_lr, xr, params, p, q, rcount)
    else
      {y, pi}
    end
  end

### END OF HELPERS ###

  def setup_nodes(param, client_add) do 
    # setup p_i, q_i, n
    {p_i, q_i, n_i} = setup_trapdoor(param) # only the node executing this process knows about p_i, q_i, whereas n_i is made public

    # generate R_0_i ie share of process i towards initial random number
    r_0_i = :rnd.random(2, n_i - 1) 

    pp = %{}
    count_pp = 1
    pp = Map.put(pp, whoami(), n_i)

    # Send a reply to client that it is ready + its share for R_0_i. 
    send(client_add, {:ready, r_0_i})
    
    {r_0, pp} = receive do
            {sender, {:ready_all_r, r_0}} ->
            # broadcast after receiving r_0
            broadcast_to_others(param, n_i)
            pp = listen_pp(param, pp, count_pp) # listen and accumulate from all the other nodes
            # send to client
            send(client_add, :ready_pp) # Gets back :ready_all_pp
            # Wait for go ahead from the client; needed to make sure that all the nodes are ready for the next steps
            receive do
              {sender, :ready_all_pp}->
                {r_0, pp} 
            end       
          end

    ## Wait till the parameter setup is done in all the nodes
    if whoami() == param.replier do
      IO.puts("Parameter exchange completed at all the nodes. Public parameters are #{inspect(pp)}")
    end
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
    ####### Parameter setup done, now onto random number generation using vdf ###########
    rcount = 0 
    become_node(state, rcount)
  end

  def become_node(state, rcount) do     
    leader_r = derive_leader(state, rcount) 
    x_r = h_in(state, leader_r)
    i = whoami()
    {y_r, pi_r} = if i == leader_r do 
                    # in this case, this node (i) is the leader of round r, so the trapdoor sk_i is used to quickly compute the VDF and broadcasted
                    # {y_r, pi_r} = Randrunner.trapdoor_eval(state.pp[lr], xr, state.params, state.p, state.q)
                    {y_r, pi_r} = generate_trapdoor(state.pp[leader_r], x_r, state.params, state.p, state.q, rcount)
                    if state.params.adversarial == false do
                      broadcast_to_others(state.params, {i, rcount, y_r, pi_r})
                    end
                    {y_r, pi_r}
                  else
                    task =  if state.params.adversarial == true do
                              Task.async(fn -> Randrunner.eval(state.pp[leader_r], x_r, state.params) end)  
                            end
                    {y_r, pi_r} = listen_y(state, rcount, leader_r, x_r)
                    # Reliable broadcast
                    if state.params.adversarial == true and state.params.reliable == true do
                      broadcast_to_others(state.params, {leader_r, i, rcount, y_r, pi_r})
                    end
                    {y_r, pi_r}                    
                  end
    
    random_r = h_out(state, y_r) # random number for the current round
    if i == state.params.replier do # For demonstration
      IO.puts("Round #{rcount}, Leader is node #{inspect(leader_r)} and the random number R_#{rcount} is #{random_r}")
    end
    send(state.client, {:ready_round, rcount, random_r})

    # wait for go ahead from the client to proceed to the next round
    receive do
      {sender, :ready_all_next_round} -> 
        become_node(%{state | r_prev: random_r}, rcount + 1)
    end
  end

  def listen_y(state, rcount, lr, xr) do
     # Listen for result of vdf from leader/other nodes (reliable broadcast) or its own task
    i = whoami()
    receive do
      # Case 1: Listen for VDF output from leader(quickest)
      {sender, {lr, rc, y, pi}} -> 
        if rcount == rc do
          if(Randrunner.verify(state.pp[lr], state.params, xr, y, pi) == true) do
            # if whoami() == state.params.replier do
            #   IO.puts("In process #{whoami()}, received from trapdoor_eval()")
            # end
            {y, pi}
          else
            listen_y(state, rcount, lr, xr)
          end
        else
          listen_y(state, rcount, lr, xr)
        end

      # Case 2: Reliable broadcast- Listen for results from other nodes (not the leader)
      {sender, {lr, i, rc, y, pi}} ->
        if rcount == rc do
          if(Randrunner.verify(state.pp[lr], state.params, xr, y, pi) == true) do
            # if whoami() == state.params.replier do
              # IO.puts("In process #{whoami()}, round #{rcount}, received from eval() of Node #{i} (Reliable broadcasting)")
            # end
            {y, pi}
          else
            listen_y(state, rcount, lr, xr)
          end
        else
          listen_y(state, rcount, lr, xr)
        end

      # Case 3: Listen for result from its own task
      {a, {y, pi}} -> 
        if(Randrunner.verify(state.pp[lr], state.params, xr, y, pi) == true) do
          # if whoami() == state.params.replier do
            # IO.puts("In process #{whoami()}, round #{rcount} received from eval() of its own task")
          # end
          {y, pi}
        else
          listen_y(state, rcount, lr, xr)
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

  ### CLIENT HELPERS ###

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

  def h_inc(r_prev, n_lr) do # r_prev is the output of previous vdf/R_0, n_lr is the public parameter of the leader. 
    s_r_prev = "#{r_prev}"
    x = :maths.mod(:binary.decode_unsigned(:crypto.hash(:sha256, s_r_prev)) ,n_lr)
    x
  end

  def h_outc(n_r, r) do
    s_r = "#{r}"
    r_out = :maths.mod(:binary.decode_unsigned(:crypto.hash(:sha256, s_r)) ,n_r)
    r_out
  end

### END OF CLIENT HELPERS ###

  def wait_random_shares(client, ok_count, received_nos) do
    views = client.params.view
    receive do 
      {sender, {:ready, r_0_i}} -> 
        ok_count = ok_count + 1

        received_nos = Map.put(received_nos, sender, r_0_i)
        
        # Once you've received all the shares, combine them, broadcast to all the nodes, then return :ready_all_r
        if(ok_count == length(views)) do 
          r_out = to_string_(Map.values(received_nos))
          r_0 = :maths.mod(:binary.decode_unsigned(:crypto.hash(:sha256, r_out)) ,client.params.n_r)

          IO.puts("Received initial shares from all the nodes. The initial random number is #{r_0}(max value is #{client.params.n_r})")
          {:ready_all_r, r_0}

        else
          wait_random_shares(client, ok_count, received_nos)
        end
      
      after # to handle the case where all the clients do not cooperate - make do with whatever we've got, assuming at least one of them will
        50_000 -> 
          r_out = to_string_(Map.values(received_nos))
          r_0 = :maths.mod(:binary.decode_unsigned(:crypto.hash(:sha256, r_out)) ,client.params.n_r)
          {:ready_all_r, r_0}
    end
  end

  def wait_pp(client, pp_count) do 
    if(pp_count != length(client.params.view)) do
      receive do
      {sender, :ready_pp} -> wait_pp(client, pp_count + 1)
      end
    else
      broadcast_to_nodes(client.params, :ready_all_pp)
      :ok
    end
  end

  def wait_node_setup(client) do 
    # Wait till the client gets :ready message from all the nodes. Once done, broadcast :ready_all_r to all the nodes 
    # so that the other nodes can proceed 
    ok_count = 0
    received_nos = %{} # to generate R_0
    {status, r_0} = wait_random_shares(client, ok_count, received_nos)
    if status == :ready_all_r do
      broadcast_to_nodes(client.params, {:ready_all_r, r_0})
      ## start listening for :ready_pp messages from all the nodes. Once you receive from all the node
      pp_count = 0
      status_pp = wait_pp(client, pp_count)
      ## broadcast :ready_all_pp
      if status_pp == :ok do
        broadcast_to_nodes(client.params, :ready_all_pp)
        :ok
      else
        :notok
      end
    else # should not reach here
      :notok
    end
  end

 
  def listen_random_node(client, res, r_count, node_count) do
    if r_count < client.params.count_r do
      receive do
        {sender, {:ready_round, r, random_r}} ->
          node_count = node_count + 1
          if(node_count == length(client.params.view)) do
            broadcast_to_nodes(client.params, :ready_all_next_round)
            listen_random_node(client, Map.put(res, r, random_r), r_count + 1, 0)
          else
            listen_random_node(client, res, r_count, node_count)
          end
      end
    else
      res
    end
  end

  def become_client(client) do   
    start = :os.system_time(:millisecond)
    # Generate an initial random seed r_0 (same number of bits as R_1, R_2 etc)
    status = wait_node_setup(client) # wait for all the nodes to be setup 
    ## r_0 is used to find the 1st leader and also as input(H(x)) to the vdf
    if status == :ok do
      IO.puts("Parameter setup completed")
      res = %{}
      r_count = 0
      node_count = 0
      res = listen_random_node(client, res, r_count, node_count)
      finish = :os.system_time(:millisecond)
      t = finish - start
      send(client.tester, {res, t})
    end
  end
end


  
