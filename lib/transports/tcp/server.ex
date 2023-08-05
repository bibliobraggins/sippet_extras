defmodule Sippet.Transports.TCP.Server do
  use ThousandIsland.Handler

  alias ThousandIsland
  alias ThousandIsland.Socket

  import Sippet.Transports.TCP

  require Logger

  alias Sippet.Message, as: Message

  @impl ThousandIsland.Handler
  def handle_connection(socket, state) do
    peer = Socket.peer_info(socket)

    connect(state[:connections], peer.address, peer.port, self())

    {:continue, state}
  end

  @impl ThousandIsland.Handler
  def handle_data(<<255, 244, 255, 253, 6>>, _socket, state) do
    Logger.warning("got ^C ::  #{inspect(<<255, 244, 255, 253, 6>>)} :: CLOSING CONNECTION")
    {:close, state}
  end

  @impl ThousandIsland.Handler
  def handle_data("\r\n\r\n", socket, state) do
    Logger.debug("got keepalive: #{inspect(Socket.peer_info(socket))}")
    {:continue, state}
  end

  @impl ThousandIsland.Handler
  def handle_data(data, socket, state) do
    peer = Socket.peer_info(socket)

    Sippet.Router.handle_transport_message(
      state[:name],
      data,
      {:tcp, peer.address, peer.port}
    )

    {:continue, state}
  end

  @impl GenServer
  def handle_info({:send_message, message}, {socket, state}) do
    with io_msg <- Message.to_iodata(message) do
      Logger.debug("Sending:\n#{to_string(message)}")
      ThousandIsland.Socket.send(socket, io_msg)
    else
      error ->
        Logger.error("Could not change message to io list. reason: #{inspect(error)}")
    end

    {:noreply, {socket, state}}
  end

  @impl ThousandIsland.Handler
  def handle_error(reason, _socket, state) do
    Logger.error("#{inspect(reason)}")
    # peer = Socket.peer_info(socket)

    {:continue, state}
  end

  @impl ThousandIsland.Handler
  def handle_timeout(_socket, state) do
    # peer = Socket.peer_info(socket)

    {:close, state}
  end

  @impl ThousandIsland.Handler
  def handle_shutdown(socket, state) do
    %{
      address: host,
      port: port,
      ssl_cert: _ssl_cert
    } = Socket.peer_info(socket)

    disconnect(state[:connections], host, port)

    Logger.debug(
      "shutting down handler #{inspect(self())} : #{inspect(stringify_hostport(host, port))}"
    )

    :ok
  end

  def stringify_hostport(host, port) do
    "#{host}:#{port}"
  end
end
