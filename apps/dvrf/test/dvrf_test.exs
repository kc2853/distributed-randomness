defmodule DvrfTest do
  use ExUnit.Case
  doctest Dvrf
  import Emulation, only: [spawn: 2, send: 2, whoami: 0]

  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]

  test "Nothing crashes during DKG setup" do
    Emulation.init()
    Emulation.append_fuzzers([Fuzzers.delay(2)])

    t = 6
    n = 10
    # Sample list of safe primes: [5, 7, 11, 23, 47, 59, 83, 107, 167, 179, 227, 263, 347, 359, 383, 467, 479, 503, 563, 587, 719, 839, 863, 887, 983, 1019, 1187, 1283, 1307, 1319, 1367, 1439, 1487, 1523, 1619, 1823, 1907]
    p = 1019
    view = [:p1, :p2, :p3, :p4, :p5, :p6, :p7, :p8, :p9, :p10]
    # Setting the following to 0 to check if DKG works first of all
    round_max = 0
    base_config =
      Dvrf.new_configuration(t, n, Dvrf.get_generator(p), p, view, round_max, "DVRF-DRB")

    spawn(:p1, fn -> Dvrf.dkg(base_config) end)
    spawn(:p2, fn -> Dvrf.dkg(base_config) end)
    spawn(:p3, fn -> Dvrf.dkg(base_config) end)
    spawn(:p4, fn -> Dvrf.dkg(base_config) end)
    spawn(:p5, fn -> Dvrf.dkg(base_config) end)
    spawn(:p6, fn -> Dvrf.dkg(base_config) end)
    spawn(:p7, fn -> Dvrf.dkg(base_config) end)
    spawn(:p8, fn -> Dvrf.dkg(base_config) end)
    spawn(:p9, fn -> Dvrf.dkg(base_config) end)
    spawn(:p10, fn -> Dvrf.dkg(base_config) end)

    client =
      spawn(:client, fn ->
        Enum.map(view, fn pid -> send(pid, :dkg) end)

        receive do
        after
          3_000 -> true
        end
      end)

    handle = Process.monitor(client)
    # Timeout.
    receive do
      {:DOWN, ^handle, _, _, _} -> true
    after
      30_000 -> assert false
    end
  after
    Emulation.terminate()
  end

  # Client listens to and logs each DRB round's output
  defp client_listen_loop(drb, round_max) do
    receive do
      {sender, {round, sign}} ->
        IO.puts "#{inspect(whoami())} Received round #{inspect(round)}, output #{inspect(sign)}"
        drb = drb ++ [sign]
        cond do
          # Completion of all the rounds
          round == round_max ->
            IO.puts "#{inspect(whoami())} Final list of outputs #{inspect(drb)}"
            drb
          # Ongoing DRB
          true ->
            client_listen_loop(drb, round_max)
        end
    end
  end

  test "DRB operates as intended when given trivial message delay" do
    Emulation.init()
    Emulation.append_fuzzers([Fuzzers.delay(2)])

    t = 6
    n = 10
    # Sample list of safe primes: [5, 7, 11, 23, 47, 59, 83, 107, 167, 179, 227, 263, 347, 359, 383, 467, 479, 503, 563, 587, 719, 839, 863, 887, 983, 1019, 1187, 1283, 1307, 1319, 1367, 1439, 1487, 1523, 1619, 1823, 1907]
    p = 1019
    view = [:p1, :p2, :p3, :p4, :p5, :p6, :p7, :p8, :p9, :p10]
    round_max = 100
    base_config =
      Dvrf.new_configuration(t, n, Dvrf.get_generator(p), p, view, round_max, "DVRF-DRB")
    replier_config =
      %{base_config | replier: true}

    spawn(:p1, fn -> Dvrf.dkg(replier_config) end)
    spawn(:p2, fn -> Dvrf.dkg(base_config) end)
    spawn(:p3, fn -> Dvrf.dkg(base_config) end)
    spawn(:p4, fn -> Dvrf.dkg(base_config) end)
    spawn(:p5, fn -> Dvrf.dkg(base_config) end)
    spawn(:p6, fn -> Dvrf.dkg(base_config) end)
    spawn(:p7, fn -> Dvrf.dkg(base_config) end)
    spawn(:p8, fn -> Dvrf.dkg(base_config) end)
    spawn(:p9, fn -> Dvrf.dkg(base_config) end)
    spawn(:p10, fn -> Dvrf.dkg(base_config) end)

    client =
      spawn(:client, fn ->
        start = :os.system_time(:millisecond)
        Enum.map(view, fn pid -> send(pid, :dkg) end)
        drb = client_listen_loop([], round_max)
        assert Enum.count(drb) == round_max
        finish = :os.system_time(:millisecond)
        IO.puts "Total time taken: #{finish - start} ms"
      end)

    handle = Process.monitor(client)
    # Timeout.
    receive do
      {:DOWN, ^handle, _, _, _} -> true
    after
      30_000 -> assert false
    end
  after
    Emulation.terminate()
  end

  test "DRB operates as intended when given nontrivial message delay" do
    Emulation.init()
    Emulation.append_fuzzers([Fuzzers.delay(500)])

    t = 6
    n = 10
    # Sample list of safe primes: [5, 7, 11, 23, 47, 59, 83, 107, 167, 179, 227, 263, 347, 359, 383, 467, 479, 503, 563, 587, 719, 839, 863, 887, 983, 1019, 1187, 1283, 1307, 1319, 1367, 1439, 1487, 1523, 1619, 1823, 1907]
    p = 1019
    view = [:p1, :p2, :p3, :p4, :p5, :p6, :p7, :p8, :p9, :p10]
    round_max = 10
    base_config =
      Dvrf.new_configuration(t, n, Dvrf.get_generator(p), p, view, round_max, "DVRF-DRB")
    replier_config =
      %{base_config | replier: true}

    spawn(:p1, fn -> Dvrf.dkg(replier_config) end)
    spawn(:p2, fn -> Dvrf.dkg(base_config) end)
    spawn(:p3, fn -> Dvrf.dkg(base_config) end)
    spawn(:p4, fn -> Dvrf.dkg(base_config) end)
    spawn(:p5, fn -> Dvrf.dkg(base_config) end)
    spawn(:p6, fn -> Dvrf.dkg(base_config) end)
    spawn(:p7, fn -> Dvrf.dkg(base_config) end)
    spawn(:p8, fn -> Dvrf.dkg(base_config) end)
    spawn(:p9, fn -> Dvrf.dkg(base_config) end)
    spawn(:p10, fn -> Dvrf.dkg(base_config) end)

    client =
      spawn(:client, fn ->
        start = :os.system_time(:millisecond)
        Enum.map(view, fn pid -> send(pid, :dkg) end)
        drb = client_listen_loop([], round_max)
        assert Enum.count(drb) == round_max
        finish = :os.system_time(:millisecond)
        IO.puts "Total time taken: #{finish - start} ms"
      end)

    handle = Process.monitor(client)
    # Timeout.
    receive do
      {:DOWN, ^handle, _, _, _} -> true
    after
      30_000 -> assert false
    end
  after
    Emulation.terminate()
  end

  test "DRB when given nontrivial message delay and multiple Byzantine nodes" do
    Emulation.init()
    Emulation.append_fuzzers([Fuzzers.delay(500)])

    t = 6
    n = 10
    # Sample list of safe primes: [5, 7, 11, 23, 47, 59, 83, 107, 167, 179, 227, 263, 347, 359, 383, 467, 479, 503, 563, 587, 719, 839, 863, 887, 983, 1019, 1187, 1283, 1307, 1319, 1367, 1439, 1487, 1523, 1619, 1823, 1907]
    p = 1019
    view = [:p1, :p2, :p3, :p4, :p5, :p6, :p7, :p8, :p9, :p10]
    round_max = 10
    base_config =
      Dvrf.new_configuration(t, n, Dvrf.get_generator(p), p, view, round_max, "DVRF-DRB")
    replier_config =
      %{base_config | replier: true}
    byzantine_config =
      %{base_config | byzantine: true}

    spawn(:p1, fn -> Dvrf.dkg(replier_config) end)
    spawn(:p2, fn -> Dvrf.dkg(byzantine_config) end)
    spawn(:p3, fn -> Dvrf.dkg(byzantine_config) end)
    spawn(:p4, fn -> Dvrf.dkg(byzantine_config) end)
    spawn(:p5, fn -> Dvrf.dkg(byzantine_config) end)
    spawn(:p6, fn -> Dvrf.dkg(base_config) end)
    spawn(:p7, fn -> Dvrf.dkg(base_config) end)
    spawn(:p8, fn -> Dvrf.dkg(base_config) end)
    spawn(:p9, fn -> Dvrf.dkg(base_config) end)
    spawn(:p10, fn -> Dvrf.dkg(base_config) end)

    client =
      spawn(:client, fn ->
        start = :os.system_time(:millisecond)
        Enum.map(view, fn pid -> send(pid, :dkg) end)
        drb = client_listen_loop([], round_max)
        assert Enum.count(drb) == round_max
        finish = :os.system_time(:millisecond)
        IO.puts "Total time taken: #{finish - start} ms"
      end)

    handle = Process.monitor(client)
    # Timeout.
    receive do
      {:DOWN, ^handle, _, _, _} -> true
    after
      30_000 -> assert false
    end
  after
    Emulation.terminate()
  end
end
