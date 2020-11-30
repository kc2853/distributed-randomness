defmodule Dvrf do
  @moduledoc """
  An implementation of the DVRF-DRB protocol.
  """
  import Emulation, only: [spawn: 2, send: 2, timer: 1, now: 0, whoami: 0]
  import Kernel, except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]
  require Fuzzers
  require Logger

  # This structure contains all the process state
  # required by the DVRF-DRB protocol.
  defstruct(
    # Threshold
    t: nil,
    # Number of participants
    n: nil,
    # Group generator of Z_q where q is prime
    g: nil,
    # Prime number (must be a safe prime: https://en.wikipedia.org/wiki/Safe_and_Sophie_Germain_primes)
    p: nil,
    # Prime number equal to (p - 1) / 2
    q: nil,
    # List of pids
    view: nil,
    # List of pids and ids
    view_id: nil,
    # Subshare from each node
    view_subshare: nil,
    # Subsignature from each node for all rounds
    view_subsign: nil,
    # Individual share used to make subsignatures for DRB
    share: nil,
    # Max number of rounds for DRB
    round_max: nil,
    # Current round for DRB
    round_current: nil,
    # Random number from the previous round
    last_output: nil,
    # Replier replies to client with each round's random number (for demonstration purposes)
    replier: nil,
    # Client receiving the sequence of random numbers (for demonstration purposes)
    client: nil,
    # Byzantine nodes (for demonstration purposes)
    byzantine: nil
  )

  @doc """
  Create state for an initial node. Each
  process should get an appropriately updated version
  of this state.
  """
  def new_configuration(
        t,
        n,
        g,
        p,
        view,
        round_max,
        last_output
      ) do
    q = trunc((p - 1) / 2)
    view_id = Enum.with_index(view, 1) |> Map.new()
    view_subshare = Enum.map(view, fn a -> {a, nil} end) |> Map.new()
    view_subsign = 1..round_max |> Enum.map(fn n ->
                                     {n, Enum.map(view, fn a -> {a, nil} end) |> Map.new()}
                                   end)
                                |> Map.new()
    %Dvrf{
      t: t,
      n: n,
      g: g,
      p: p,
      q: q,
      view: view,
      view_id: view_id,
      view_subshare: view_subshare,
      view_subsign: view_subsign,
      round_max: round_max,
      round_current: 0,
      last_output: last_output,
      replier: false,
      byzantine: false
    }
  end

  # Generator (primitive root) of Z_q where q is a prime number equal to (p - 1) / 2
  def get_generator(p) do
    get_generator(p, 2)
  end

  # Algorithm 4.86 from http://cacr.uwaterloo.ca/hac/about/chap4.pdf
  defp get_generator(p, x) do
    cond do
      # Find a generator of (Z_p)* first
      # then square it to get a generator of Z_q
      :maths.mod_exp(x, 2, p) != 1 && :maths.mod_exp(x, trunc((p - 1) / 2), p) != 1 ->
        # IO.puts "Generator: #{inspect(:maths.mod_exp(x, 2, p))}"
        :maths.mod_exp(x, 2, p)
      true ->
        get_generator(p, x + 1)
    end
  end

  # We start n parallel instances of VSS (verifiable secret sharing)
  def get_poly_then_send(state) do
    # Generate t number of random coefficients in (Z_p)*
    coeff = Enum.map(1..state.t, fn _ -> :rand.uniform(state.p - 1) end)
    comm = get_comm(coeff, state.g, state.p)

    # Correctly send corresponding subshares to each node
    state.view
    |> Enum.filter(fn pid -> pid != whoami() end)
    |> Enum.map(fn pid ->
         id = Map.get(state.view_id, pid)
         subshare = get_subshare(coeff, id)
         msg = {subshare, comm}
         send(pid, msg)
       end)

    # Calculate my subshare and update state
    id_me = Map.get(state.view_id, whoami())
    subshare_me = get_subshare(coeff, id_me)
    state = %{state | view_subshare: Map.put(state.view_subshare, whoami(), subshare_me)}
    state
  end

  # We commit to coefficients by raising g (group generator) to the power of each coefficient
  def get_comm(coeff, g, p) do
    # :maths belongs to ndpar library
    Enum.map(coeff, fn x -> :maths.mod_exp(g, x, p) end)
  end

  # Horner's method for polynomial evaluation (at id)
  def get_subshare(coeff, id) do
    Enum.reduce(Enum.reverse(coeff), 0, fn x, acc -> x + acc * id end)
  end

  # Verify a subshare as per VSS (verifiable secret sharing)
  def verify_subshare(subshare, comm, g, p, id) do
    lhs = :maths.mod_exp(g, subshare, p)
    rhs = Enum.with_index(comm)
    rhs = Enum.map(rhs, fn t -> :maths.mod_exp(elem(t, 0), :maths.pow(id, elem(t, 1)), p) end)
    rhs = Enum.reduce(rhs, fn x, acc -> :maths.mod(x * acc, p) end)
    lhs == rhs
  end

  # Above are utility functions before DKG
  # Below is DKG

  # Distributed key generation
  def dkg(state) do
    dkg(state, 0)
  end

  # Counter counts how many subshares one has received so far (need n)
  # Note (QUAL assumption): In the literature, the usual assumption is that some nodes could be
  # unresponsive/faulty/Byzantine in the DKG phase (pre-DRB phase), in which case
  # nodes first need to agree on a group of qualified nodes (denoted by QUAL) during DKG.
  # Here, we assume that all initialized nodes are honest and fully functional
  # in the DKG phase (perhaps not in the DRB phase later though). In other words,
  # all nodes are in QUAL, so the number of nodes in QUAL is n.
  defp dkg(state, counter) do
    receive do
      # Receive start order for DKG
      {sender, :dkg} ->
        IO.puts "#{inspect(whoami())} Received :dkg"
        state = %{state | client: sender}
        state = get_poly_then_send(state)
        counter = counter + 1
        cond do
          # This can happen if the network is highly unstable such that the :dkg message
          # from the client reaches a node last (compared to subshare messages)
          counter == state.n ->
            subshares = Map.values(state.view_subshare)
            share = Enum.sum(subshares)
            state = %{state | share: share}
            IO.puts "#{inspect(whoami())} Exits DKG due to #{inspect(sender)}, share is #{inspect(state.share)}"
            drb_next_round(state)
          # Normal cases
          true ->
            dkg(state, counter)
        end

      # Listen mode for subshares
      {sender, {subshare, comm}} ->
        # IO.puts "#{inspect(whoami())} Received subshare from #{inspect(sender)}"
        id_me = Map.get(state.view_id, whoami())
        case verify_subshare(subshare, comm, state.g, state.p, id_me) do
          # We should not end up here due to our QUAL assumption from the outset
          false ->
            raise "QUAL assumption violated"
          # Normal cases
          true ->
            state = %{state | view_subshare: Map.put(state.view_subshare, sender, subshare)}
            counter = counter + 1
            cond do
              # Need to wait for more subshares
              counter < state.n ->
                dkg(state, counter)
              # Can make a share out of all subshares received
              true ->
                subshares = Map.values(state.view_subshare)
                share = Enum.sum(subshares)
                state = %{state | share: share}
                IO.puts "#{inspect(whoami())} Exits DKG due to #{inspect(sender)}, share is #{inspect(state.share)}"
                drb_next_round(state)
            end
        end
    end
  end

  # Note (Chaum-Pedersen NIZK): We show via zero-knowledge that
  # the two discrete logs -- log of h1 with base g1 and log of h2
  # with base g2 -- are equal. In particular, the exact value of
  # the discrete log is in fact equal to a node's secret share,
  # which the node used to "sign" DRB's round message to generate
  # a subsignature. Hence, this NIZK proves the connection between
  # the previous DKG and the ongoing DRB.
  def get_nizk(g1, h1, g2, h2, p, q, share) do
    w = :rand.uniform(q)
    a1 = :maths.mod_exp(g1, w, p)
    a2 = :maths.mod_exp(g2, w, p)
    params = ["#{h1}", "#{h2}", "#{a1}", "#{a2}"]
    # Fiat-Shamir heuristic
    # A different hash function used just for NIZK purposes
    c = :crypto.hash(:sha224, params) |> :binary.decode_unsigned |> :maths.mod(q)
    r = :maths.mod(w - share * c, q)
    {a1, a2, r}
  end

  # Anyone can non-interactively verify NIZK by definition
  # Note: In a public bulletin model, one would be able to verify
  # a NIZK without `state` (which only the participants to the DRB
  # have access to in this implementation), as parameters (e.g. p, q, and g)
  # would be available to everyone (including bystanders).
  def verify_nizk(subsign, nizk_msg, state) do
    {nizk, comm_to_share, hash} = nizk_msg
    {a1, a2, r} = nizk
    {p, q} = {state.p, state.q}
    lhs1 = a1
    lhs2 = a2
    params = ["#{comm_to_share}", "#{subsign}", "#{a1}", "#{a2}"]
    c = :crypto.hash(:sha224, params) |> :binary.decode_unsigned |> :maths.mod(q)
    rhs1 = :maths.mod_exp(state.g, r, p) * :maths.mod_exp(comm_to_share, c, p) |> :maths.mod(p)
    rhs2 = :maths.mod_exp(hash, r, p) * :maths.mod_exp(subsign, c, p) |> :maths.mod(p)
    lhs1 == rhs1 && lhs2 == rhs2
  end

  # Lagrange interpolation from t number of subsignatures
  # Note: We make use of a pleasantly surprising fact that we would end up
  # with the same output regardless of which t number of subsignatures we get.
  def get_sign(subsigns, p, q) do
    lambda_set = Enum.map(subsigns, fn x -> elem(x, 0) end)
    Enum.map(subsigns, fn x ->
      subsign = elem(x, 1)
      lambda = get_lambda(lambda_set, elem(x, 0), q)
      :maths.mod_exp(subsign, lambda, p)
    end)
    |> Enum.reduce(fn x, acc -> :maths.mod(x * acc, p) end)
  end

  # Lagrange interpolation constants
  # Note: This is the main reason why we use q from a safe prime.
  # Congruency modulo q on the exponent yields congruency modulo p
  # on the base. Hence, we chose a safe prime.
  def get_lambda(lambda_set, i, q) do
    # We work with modulo q (not p) when dealing with exponents
    Enum.filter(lambda_set, fn x -> x != i end)
    |> Enum.map(fn j ->
         # Below `cond do` is b/c :maths.mod_inv() cannot deal with negative numbers
         cond do
           j / (j - i) < 0 ->
             # Can't perform :maths.mod_inv() if q is not prime
             :maths.mod(-j, q) * :maths.mod_inv(i - j, q)
           j / (j - i) > 0 ->
             :maths.mod(j, q) * :maths.mod_inv(j - i, q)
           true ->
             raise "Should not get any zero when calculating lambda"
         end
       end)
    |> Enum.reduce(fn x, acc -> :maths.mod(x * acc, q) end)
  end

  # Update `view_subsign` for a specific round
  def get_updated_view_subsign(view, round, pid, subsign) do
    res = Map.put(view[round], pid, subsign)
    Map.put(view, round, res)
  end

  # Above are utility functions before DRB
  # Below is DRB

  # Transitioning into the next round of DRB
  def drb_next_round(state) do
    state = %{state | round_current: state.round_current + 1}
    cond do
      # Successful completion of DRB
      state.round_current > state.round_max ->
        # IO.puts "#{inspect(whoami())} Successfully completed!"
        nil
      # Ongoing DRB
      true ->
        msg = ["#{state.last_output}", "#{state.round_current}"]
        # We want hash to be part of Z_q subgroup of (Z_p)*
        hash = :crypto.hash(:sha256, msg) |> :binary.decode_unsigned |> :maths.mod(state.q)
        hash = :maths.mod_exp(state.g, hash, state.p)
        subsign = :maths.mod_exp(hash, state.share, state.p)
        comm_to_share = :maths.mod_exp(state.g, state.share, state.p)
        nizk = get_nizk(state.g, comm_to_share, hash, subsign, state.p, state.q, state.share)
        # Some of the inputs to NIZK are kindly provided by the sender for convenience
        # although all of them can be publicly computed anyways
        nizk_msg = {nizk, comm_to_share, hash}
        msg = {subsign, nizk_msg, state.round_current}

        # Broadcasting (subsign, nizk_msg)
        cond do
          # Broadcasting invalid subsignature and NIZK if Byzantine
          state.byzantine == true ->
            {p, q} = {state.p, state.q}
            nizk_byzantine = {:rand.uniform(p - 1), :rand.uniform(p - 1), :rand.uniform(q)}
            nizk_msg_byzantine = {nizk_byzantine, :rand.uniform(p - 1), :rand.uniform(p - 1)}
            msg_byzantine = {:rand.uniform(p - 1), nizk_msg_byzantine, state.round_current}
            state.view
            |> Enum.filter(fn pid -> pid != whoami() end)
            |> Enum.map(fn pid -> send(pid, msg_byzantine) end)
          # Honest broadcast
          state.byzantine == false ->
            state.view
            |> Enum.filter(fn pid -> pid != whoami() end)
            |> Enum.map(fn pid -> send(pid, msg) end)
        end

        # Update state by recording my new subsignature
        new = get_updated_view_subsign(state.view_subsign, state.round_current, whoami(), subsign)
        state = %{state | view_subsign: new}
        counter = Map.values(state.view_subsign[state.round_current]) |> Enum.count(fn x -> x != nil end)
        cond do
          # There are already at least t number of subsignatures received for the round,
          # which can happen if the network is highly unstable
          counter >= state.t ->
            IO.puts "#{inspect(whoami())} Already threshold passed due to unstable network"
            drb_round_finish(state)
          # Need to listen for more subsignatures until at least t is reached
          true ->
            # IO.puts "#{inspect(whoami())} Entering DRB round #{state.round_current}, counter #{counter}"
            drb(state, counter)
        end
    end
  end

  # Distributed randomness beacon
  # Counter counts how many subsignatures one has received so far (need t)
  def drb(state, counter) do
    receive do
      {sender, {subsign, nizk_msg, round}} ->
        cond do
          # Can ignore message from a previous round
          round < state.round_current ->
            drb(state, counter)
          # Check if NIZK returns true
          verify_nizk(subsign, nizk_msg, state) == false ->
            # IO.puts "#{inspect(whoami())} Invalid NIZK"
            drb(state, counter)
          # Message from a future round
          round > state.round_current ->
            new = get_updated_view_subsign(state.view_subsign, round, sender, subsign)
            state = %{state | view_subsign: new}
            drb(state, counter)
          # Message from the current round
          true ->
            new = get_updated_view_subsign(state.view_subsign, round, sender, subsign)
            state = %{state | view_subsign: new}
            counter = counter + 1
            cond do
              # Need to wait for at least t number of subsignatures
              counter < state.t ->
                drb(state, counter)
              # Can make a signature (= round output) out of t subsignatures received
              true ->
                drb_round_finish(state)
            end
        end
    end
  end

  # Wrap up the current round and move on to the next
  def drb_round_finish(state) do
    subsigns = Map.to_list(state.view_subsign[state.round_current])
               |> Enum.filter(fn x -> elem(x, 1) != nil end)
               |> Enum.map(fn x -> {Map.get(state.view_id, elem(x, 0)), elem(x, 1)} end)
    # Lagrange interpolation
    sign = get_sign(subsigns, state.p, state.q)
    state = %{state | last_output: sign}
    # IO.puts "#{inspect(whoami())} Output for round #{inspect(state.round_current)} is #{inspect(sign)}"
    cond do
      # Send the randomness beacon output to client (for dev purposes)
      state.replier == true ->
        send(state.client, {state.round_current, sign})
        drb_next_round(state)
      # Normal cases
      true ->
        drb_next_round(state)
    end
  end
end
