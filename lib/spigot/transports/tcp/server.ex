defmodule Spigot.Transports.TCPServer do
  use ThousandIsland.Handler

  alias ThousandIsland
  alias ThousandIsland.Socket, as: Socket
  alias Spigot.Connections
  alias Sippet.Message, as: Message

  require Logger

  @impl ThousandIsland.Handler
  def handle_connection(_socket, state) do
    reference = :erlang.make_ref()
    Connections.connect(state[:connections], reference, self())
    {:continue, Keyword.put(state, :reference, reference)}
  end

  @keepalive <<13, 10, 13, 10>>
  @impl ThousandIsland.Handler
  def handle_data(@keepalive, _socket, state), do: {:continue, state}

  @exit_code <<255, 244, 255, 253, 6>>
  @impl ThousandIsland.Handler
  def handle_data(@exit_code, _socket, state), do: {:close, state}

  @impl ThousandIsland.Handler
  def handle_data(data, socket, state) do
    with {:ok, message} <- Message.parse(data),
        response <- apply(state[:user_agent], :handle_request, [message])
      do
        ThousandIsland.Socket.send(socket, response)
      else
        reason ->
          Logger.error("could not parse message from #{inspect(Socket.peer_info(socket))} :: reason: #{reason}")
    end

    {:continue, state}
  end

  @impl GenServer
  def handle_info({:send_message, message}, {socket, state}) do
    with io_msg <- Message.to_iodata(message) do
      Logger.debug("Sending:\n#{to_string(message)}")
      ThousandIsland.Socket.send(socket, io_msg) |> Logger.debug()
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
    Connections.disconnect(state[:connections], state[:reference])
  end

  @impl ThousandIsland.Handler
  def handle_shutdown(socket, state) do
    %{
      address: host,
      port: port,
      ssl_cert: _ssl_cert
    } = Socket.peer_info(socket)

    case Connections.lookup(state[:connections], state[:peer]) do
      [_] ->
        Connections.disconnect(state[:connections], state[:peer])

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
