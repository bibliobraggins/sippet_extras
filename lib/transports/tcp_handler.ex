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
      state[:owner],
      {:register, {address, port}, self()}
    )

    {:continue, state}
  end

  @impl ThousandIsland.Handler
  def handle_data(data, socket, state) do
    peer = Socket.peer_info(socket)

    case Message.parse(data) do
      {:ok, %Message{}} ->
        Logger.debug(inspect(data))

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

  def handle_info({:send_message, message}, {socket, state}) do
    ThousandIsland.Socket.send(socket, message)
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
