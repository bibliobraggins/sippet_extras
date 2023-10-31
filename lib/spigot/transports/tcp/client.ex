defmodule Spigot.Transports.Tcp.Client do
  alias Spigot.{Transport}

  use GenServer

  @spec start_link(
          binary() | :inet.hostname(),
          :inet.port_number(),
          non_neg_integer(),
          keyword() | list()
        ) ::
          :ignore | {:error, any()} | {:ok, pid()}
  def start_link(spigot, host, port \\ 5060, timeout \\ 10_000, family \\ :inet, options \\ []) do
    host =
      if is_binary(host) do
        Transport.resolve_name(host, family)
      else
        host
      end

    state = [
      spigot: spigot,
      connections: Transport.table(spigot),
      host: host,
      port: port,
      family: family,
      timeout: timeout
    ]

    GenServer.start_link(__MODULE__, state, options)
  end

  def connect(state) do
    :gen_tcp.connect(state[:host], state[:port], [
      state[:family],
      :binary,
      packet: :line,
      active: true
    ])
  end

  def init(state) do
    case connect(state) do
      {:ok, socket} ->
        Map.put(state, :socket, socket)
    end

    {:ok, state}
  end

  def handle_info({:tcp, _socket, _data}, state) do
    # Spigot.Router.handle_transport_message/4

    {:noreply, state}
  end

  def handle_info({:send_message, io_msg}, state) do
    :gen_tcp.send(state[:socket], io_msg)
    {:noreply, state}
  end
end
