defmodule Spigot.Transports.TCP.Server do
  use ThousandIsland.Handler

  alias ThousandIsland.{Socket}
  alias Spigot.{Connections}
  alias Sippet.{Message}

  require Logger

  @impl ThousandIsland.Handler
  def handle_connection(socket, state) do
    with {:ok, {_host, _port} = peer} <- Socket.peername(socket) do
      state =
        Keyword.put(state, :peer, peer)

      Connections.connect(state[:connections], peer, self())

      {:continue, state}
    else
      error ->
        Logger.error(inspect(error))
        {:close, state}
    end
  end

  @exit_code <<255, 244, 255, 253, 6>>
  @impl ThousandIsland.Handler
  def handle_data(@exit_code, _socket, state), do: {:close, state}

  @impl ThousandIsland.Handler
  def handle_data(data, _socket, state) do
    {host, port} = state[:peer]

    Spigot.Router.handle_transport_message(
      data,
      {:tcp, host, port},
      state[:user_agent],
      state[:spigot]
    )

    {:continue, state}
  end

  @impl GenServer
  def handle_info({:send_message, msg}, {socket, state}) do
    io_msg = Message.to_iodata(msg)

    with :ok <- ThousandIsland.Socket.send(socket, io_msg) do
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
    {address, port} = state[:peer]

    Connections.disconnect(state[:connections], {address, port})

    Process.exit(self(), reason)
  end
end
