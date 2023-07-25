defmodule Sippet.Transports.TCP.Server do
  use ThousandIsland.Handler

  alias ThousandIsland
  alias ThousandIsland.Socket

  require Logger

  alias Sippet.Message, as: Message

  @impl ThousandIsland.Handler
  def handle_connection(socket, state) do
    peer = Socket.peer_info(socket)

    register_conn(state[:registry], peer.address, peer.port)

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

    {:continue, state}
  end

  @impl ThousandIsland.Handler
  def handle_timeout(socket, state) do
    _peer = Socket.peer_info(socket)

    {:close, state}
  end

  @impl ThousandIsland.Handler
  def handle_shutdown(socket, _state) do
    %{
      address: address,
      port: port,
      ssl_cert: _ssl_cert
    } = Socket.peer_info(socket)

    Logger.debug(
      "shutting down handler #{inspect(self())} : #{stringify_hostport(address, port)}"
    )

    :ok
  end

  defp register_conn(registry, to_host, to_port) do
    try do
      GenServer.call(registry, {:register, to_host, to_port})
    rescue
      reason ->
        Logger.emergency(
          "could not lookup handler pid, registry process is not responsive, reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def unregister_conn(registry, to_host, to_port) do
    try do
      GenServer.call(registry, {:unregister, to_host, to_port})
    rescue
      reason ->
        Logger.emergency(
          "could not lookup handler pid, registry process is not responsive, reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
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
