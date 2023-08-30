defmodule Spigot.Transports.TCP.Server do
  use ThousandIsland.Handler

  alias ThousandIsland
  alias ThousandIsland.Socket
  alias Sippet.Message, as: Message
  alias Spigot.Transports.TCP

  require Logger

  @impl ThousandIsland.Handler
  def handle_connection(socket, state) do
    peer = Socket.peer_info(socket)
    TCP.connect(state[:connections], peer, self())
    {:continue, Keyword.put(state, :conn, TCP.key(peer.address, peer.port))}
  end

  @keepalive <<13, 10, 13, 10>>
  @impl ThousandIsland.Handler
  def handle_data(@keepalive, _socket, state), do: {:continue, state}

  @exit_code <<255, 244, 255, 253, 6>>
  @impl ThousandIsland.Handler
  def handle_data(@exit_code, _socket, state), do: {:close, state}

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
        Logger.error(
          "Could not change message to io list. reason: #{inspect(error)}\n#{inspect(message)}"
        )
    end

    {:noreply, {socket, state}}
  end

  @impl ThousandIsland.Handler
  def handle_error(reason, _socket, state) do
    Logger.error("#{inspect(self())}|#{inspect(reason)}")
    {:continue, state}
  end

  @impl ThousandIsland.Handler
  def handle_timeout(_socket, state), do: {:close, state}

  @impl ThousandIsland.Handler
  def handle_close(_socket, state) do
    TCP.disconnect(state[:connections], state[:conn])

    :ok
  end

  @impl ThousandIsland.Handler
  def handle_shutdown(socket, state) do
    %{
      address: host,
      port: port,
      ssl_cert: _ssl_cert
    } = Socket.peer_info(socket)

    case TCP.lookup_conn(state[:connections], state[:peer]) do
      [_] ->
        TCP.disconnect(state[:connections], state[:peer])

      _ ->
        nil
    end

    Logger.debug("shutting down handler #{inspect(self())} : #{stringify_hostport(host, port)}")

    :ok
  end

  def stringify_hostport(host, port) when is_tuple(host) do
    "#{host |> :inet.ntoa() |> to_string()}:#{port}"
  end
end
