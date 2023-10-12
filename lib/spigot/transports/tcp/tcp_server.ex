defmodule Spigot.Transports.TCP.Server do
  use ThousandIsland.Handler

  alias ThousandIsland.{Socket}
  alias Spigot.{Connections}

  require Logger

  @impl ThousandIsland.Handler
  def handle_connection(socket, state) do
    peer = Socket.peer_info(socket)

    Connections.connect(state[:connections], {peer.address, peer.port}, self())

    state =
      state
      |> Keyword.put(:peer, peer)

    # |> Keyword.put(:socket, socket)

    {:continue, state}
  end

  @exit_code <<255, 244, 255, 253, 6>>
  @impl ThousandIsland.Handler
  def handle_data(@exit_code, _socket, state), do: {:close, state}

  @impl ThousandIsland.Handler
  def handle_data(data, _socket, state) do
    peer = state[:peer]

    IO.puts("#{inspect(self())}")

    Spigot.Router.handle_transport_message(
      data,
      {:tcp, peer.address, peer.port},
      state[:user_agent],
      state[:spigot]
    )

    {:continue, state}
  end

  @impl GenServer
  def handle_info({:send_message, io_msg}, {socket, state}) do

    with :ok <- ThousandIsland.Socket.send(socket, io_msg) do
      peer = state[:peer]
      Connections.disconnect(state[:connections], {peer.address, peer.port})
      {:noreply, {socket, state}}
    else
      err ->
        Logger.warning("#{inspect(err)}")
        {:noreply, {socket, state}}
    end

  end

  @impl GenServer
  def handle_info({:send_message, _io_msg}, state) do
    Logger.error("this process does not have a socket to transmit on #{inspect(self())}")

    {:shutdown, state}
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

  def terminate(reason, state) do
    peer = state[:peer]

    Connections.disconnect(state[:connections], {peer.address, peer.port})

    Logger.warning("closing: #{inspect(self())}, reason: #{inspect(reason)}")

    Process.exit(self(), reason)
  end
end
