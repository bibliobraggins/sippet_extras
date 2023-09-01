defmodule Spigot.Test.TCP do
  use ExUnit.Case

  alias Spigot.UserAgent.Utils, as: Utils
  alias Sippet.Message, as: Msg

  require Logger

  setup_all do
    {:ok, ip_list} = :inet.getifaddrs()

    [eth0_info] =
      for {interface, net_info} <- ip_list, interface == ~c"eth0", do: net_info

    addr = eth0_info[:addr]

    addr_s = addr |> :inet.ntoa() |> to_string()

    connections =
      :ets.new(:test_tcp_transport, [
        :named_table,
        :set,
        :public,
        {:write_concurrency, true}
      ])

    {:ok,
     net_interface: eth0_info,
     peer: %{
       address: {192, 168, 3, 186},
       port: 5062
     },
     connections: connections,
     addr: addr,
     addr_s: addr_s}
  end

  alias Sippet.Message, as: Msg

  test "tcp client connects", state do
    Logger.debug(inspect(test_msg(state)))

    Spigot.Transport.TCP.Client.start_link(
      connections: :test_tcp_transport,
      start_message: test_msg(state),
      timeout: 10_000,
      peer: %{
        address: {192, 168, 3, 186},
        port: 5062,
        ssl_cert: nil
      }
    )

    Process.sleep(:infinity)
  end

  defp close do
    :ets.delete(:test_tcp_transport)
  end

  defp test_msg(state) do
    addr = state[:net_interface][:addr]

    msg =
      Msg.build_request(:options, "sip:test@#{state[:addr_s]}")
      |> Msg.put_header(:cseq, {0, :options})
      |> Msg.put_header_front(
        :via,
        {{2, 0}, :tcp, {state[:addr_s], 5060}, %{"branch" => Msg.create_branch()}}
      )
      |> Msg.put_header(
        :from,
        {"test", Sippet.URI.parse!("sip:test@#{state[:addr_s]}"), %{"tag" => Msg.create_tag()}}
      )
      |> Msg.put_header(
        :to,
        {"1000",
         Sippet.URI.parse!("1000@#{host_string(state[:peer].address)}:#{state[:peer].port}"),
         %{"tag" => Msg.create_tag()}}
      )
      |> Msg.put_header(:call_id, Msg.create_call_id())
  end

  defp host_string(host) do
    :inet.ntoa(host)
    |> to_string()
  end
end
