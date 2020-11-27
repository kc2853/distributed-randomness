defmodule Dvrf do
  @moduledoc """
  An implementation of the DVRF-DRB protocol.
  """
  import Emulation, only: [spawn: 2, send: 2, timer: 1, now: 0, whoami: 0]

  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]

  require Fuzzers
  # This allows you to use Elixir's loggers
  # for messages. See
  # https://timber.io/blog/the-ultimate-guide-to-logging-in-elixir/
  # if you are interested in this. Note we currently purge all logs
  # below Info
  require Logger

  # This structure contains all the process state
  # required by the DVRF-DRB protocol.
  defstruct(
    # Threshold
    t: nil,
    # Number of participants
    n: nil,
    # Group generator
    g: nil,
    # Prime number (must be a safe prime: https://en.wikipedia.org/wiki/Safe_and_Sophie_Germain_primes)
    p: nil,
    # List of pids
    view: nil,
    # List of pids and ids
    view_id: nil,
    # Subshare from each node
    view_subshare: nil,
    # Individual share used to make signatures for DRB
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
    client: nil
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
    view_id = Enum.with_index(view, 1) |> Map.new()
    view_subshare = Enum.map(view, fn a -> {a, nil} end) |> Map.new()
    %Dvrf{
      t: t,
      n: n,
      g: g,
      p: p,
      view: view,
      view_id: view_id,
      view_subshare: view_subshare,
      round_max: round_max,
      round_current: 0,
      last_output: last_output,
      replier: false,
    }
  end

  # Generator (primitive root) of Z_p where p is a safe prime
  def get_generator(p) do
    get_generator(p, 2)
  end

  defp get_generator(p, x) do
    cond do
      # trunc() converts float to integer
      :maths.mod_exp(x, 2, p) != 1 && :maths.mod_exp(x, trunc((p - 1) / 2), p) != 1 ->
        x
      true ->
        get_generator(p, x + 1)
    end
  end

  def get_poly_then_send(state) do
    # Generate t number of random coefficients in Z_p
    coeff = Enum.map(1..state.t, fn _ -> :rand.uniform(state.p - 1) end)
    comm = get_comm(coeff, state.g, state.p)

    # Correctly send corresponding subshares to each node
    state.view
    |> Enum.filter(fn pid -> pid != whoami() end)
    |> Enum.map(fn pid ->
        id = Map.get(state.view_id, pid)
        subshare = get_subshare(coeff, id, state.p)
        msg = {subshare, comm}
        send(pid, msg)
      end)

    # Calculate my subshare and update state
    id_me = Map.get(state.view_id, whoami())
    subshare_me = get_subshare(coeff, id_me, state.p)
    state = %{state | view_subshare: Map.put(state.view_subshare, whoami(), subshare_me)}
    state
  end

  # We commit to coefficients by raising g (group generator) to the power of each coefficient
  def get_comm(coeff, g, p) do
    # :maths belongs to ndpar library
    Enum.map(coeff, fn x -> :maths.mod_exp(g, x, p) end)
  end

  # Horner's method for polynomial evaluation (at id)
  def get_subshare(coeff, id, p) do
    res = Enum.reduce(Enum.reverse(coeff), 0, fn x, acc -> x + acc * id end)
    res = :maths.mod(res, p)
    res
  end

  # Distributed key generation
  def dkg(state) do
    dkg(state, 0)
  end

  # Counter counts how many subshares one has received so far (need n)
  # QUAL assumption: In the literature, the usual assumption is that some nodes could be
  # unresponsive/faulty/Byzantine in the DKG phase (pre-DRB phase), in which case
  # nodes first need to agree on a group of qualified nodes (denoted by QUAL) during DKG.
  # Here, we assume that all initialized nodes are honest and fully functional
  # in the DKG phase (perhaps not in the DRB phase later though). In other words,
  # all nodes are in QUAL, so the number of nodes in QUAL is n.
  defp dkg(state, counter) do
    receive do
      # Receive start order for DKG
      {sender, :dkg} ->
        IO.puts "Received :dkg"
        state = %{state | client: sender}
        state = get_poly_then_send(state)
        dkg(state, counter + 1)

      # Listen mode for subshares
      {sender, {subshare, comm}} ->
        IO.puts "Received subshare from #{inspect(sender)} to #{inspect(whoami())}"
        id_me = Map.get(state.view_id, whoami())
        case verify_subshare(subshare, comm, state.g, state.p, id_me) do
          false ->
            # We should not end up here due to our QUAL assumption from the outset
            raise "QUAL assumption violated"
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
                share = :maths.mod(Enum.sum(subshares), state.p)
                state = %{state | share: share}
                drb_next_round(state)
            end
        end
    end
  end

  def verify_subshare(subshare, comm, g, p, id) do
    # TODO: VSS verification
    true
  end

  def drb_next_round(state) do
    # TODO: Send subsign and NIZK for the next DRB round
    state = %{state | round_current: state.round_current + 1}
    # Sign message = (previous random || round_current)
    # Make NIZK that the message was signed with secret key = polynomial share from previous
    # Broadcast (subsign, nizk)
    # Record my subsign + need to add an entry to defstruct?
    drb(state, 1)
  end

  # Counter counts how many subsignatures one has received so far (need t)
  defp drb(state, counter) do
    # TODO: Listen mode for DRB
    # receive do
    # end
    IO.puts "Process #{inspect(whoami())} got to DRB phase, share is #{inspect(state.share)}"
  end
end
