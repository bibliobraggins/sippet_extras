defmodule Spigot.Transports.TCP.ConnectionHandler do
  use ThousandIsland.Handler

  alias ThousandIsland
  alias ThousandIsland.Socket, as: Socket
  alias Sippet.Message, as: Message

  require Logger

  @impl ThousandIsland.Handler
  def handle_connection(_socket, state) do
    reference = :erlang.make_ref()
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
        # use a route attribute in the provided user_agent to clean this up, using apply/3 is undesirable.
        response <- apply(state[:user_agent], :handle_request, [message]),
        io_response <- Message.to_iodata(response)
      do
        ThousandIsland.Socket.send(socket, io_response)
      else
        reason ->
          Logger.error("could not parse message from #{inspect(Socket.peer_info(socket))} :: reason: #{reason}")
    end

    {:continue, state}
  end

  @impl ThousandIsland.Handler
  def handle_error(reason, _socket, state) do
    Logger.error("#{inspect(self())}|#{inspect(reason)}")
    {:continue, state}
  end

  @impl ThousandIsland.Handler
  def handle_timeout(_socket, state), do: {:close, state}

  @impl ThousandIsland.Handler
  def handle_close(_socket, state), do: {:shutdown, state}

  @impl ThousandIsland.Handler
  def handle_shutdown(_socket, _state) do
    :ok
  end

  def stringify_hostport(host, port) when is_tuple(host) do
    "#{host |> :inet.ntoa() |> to_string()}:#{port}"
  end
end
