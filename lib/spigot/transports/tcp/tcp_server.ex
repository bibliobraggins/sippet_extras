defmodule Spigot.Transports.TCP.Server do
  use ThousandIsland.Handler

  alias ThousandIsland.Socket
  alias ThousandIsland

  require Logger

  @impl ThousandIsland.Handler
  def handle_connection(_socket, state) do
    state = state

    {:continue, state}
  end

  @exit_code <<255, 244, 255, 253, 6>>
  @impl ThousandIsland.Handler
  def handle_data(@exit_code, _socket, state), do: {:close, state}

  @impl ThousandIsland.Handler
  def handle_data(data, socket, state) do
    peer = Socket.peer_info(socket)

    Spigot.Router.handle_transport_message(
      data,
      {:tcp, peer.address, peer.port},
      state[:user_agent],
      state[:socket]
    )

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
  def handle_shutdown(_socket, _state), do: :ok

  def stringify_hostport(host, port) when is_tuple(host),
    do: "#{host |> :inet.ntoa() |> to_string()}:#{port}"
end
