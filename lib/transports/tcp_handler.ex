defmodule Sippet.Transports.TcpHandler do
  use ThousandIsland.Handler

  alias ThousandIsland
  alias ThousandIsland.Socket

  require Logger

  alias Sippet.Message, as: Message

  @impl ThousandIsland.Handler
  def handle_connection(socket, state) do
    %{
      address: address,
      port: port,
      ssl_cert: _ssl_cert
    } = Socket.peer_info(socket)

    GenServer.cast(
      state[:socket],
      {:register, {address, port}, self()}
    )

    {:continue, state}
  end

  @impl ThousandIsland.Handler
  def handle_data("\r\n\r\n", _socket, state) do
    {:continue, state}
  end

  @impl ThousandIsland.Handler
  def handle_data(data, socket, state) do
    peer = Socket.peer_info(socket)

    case Message.parse(data) do
      {:ok, %Message{}} ->
        Sippet.Router.handle_transport_message(
          state[:name],
          data,
          {:tcp, peer.address, peer.port}
        )

      _ ->
        Logger.warning(
          "could not parse message #{data} from #{inspect(peer.address)}:#{inspect(peer.port)}"
        )
    end

    {:continue, state}
  end

  @impl GenServer
  def handle_info({:send_message, message}, {socket, state}) do
    with io_msg <- Message.to_iodata(message) do
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

    {:continue, state}
  end

  @impl ThousandIsland.Handler
  def handle_timeout(_socket, state) do
    {:close, state}
  end

  @impl ThousandIsland.Handler
  def handle_shutdown(socket, state) do
    %{
      address: address,
      port: port,
      ssl_cert: _ssl_cert
    } = Socket.peer_info(socket)

    GenServer.cast(
      state[:socket],
      {:unregister, {address, port}}
    )

    Logger.debug("shutting down handler #{inspect(self())} : #{stringify_hostport(address, port)}")

    :ok
  end

  def stringify_sockname(socket) do
    {:ok, {ip, port}} = :inet.sockname(socket)

    address =
      ip
      |> :inet_parse.ntoa()
      |> to_string()

    "#{address}:#{port}"
  end

  def stringify_hostport(host, port) do
    "#{host}:#{port}"
  end
end
