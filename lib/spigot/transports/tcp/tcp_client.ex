defmodule Spigot.Transports.Tcp.Client do
  use GenServer

  def start_link(options) do
    genserver_options =
      Keyword.get(options, :genserver_options, [])

    options = Keyword.delete(options, :genserver_options)

    GenServer.start_link(__MODULE__, options, genserver_options)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_info({:tcp, _socket, _data}, state) do
    # Spigot.Router.handle_transport_message/4

    {:noreply, state}
  end

  def handle_info({:send_message, io_msg}, state) do
    :gen_tcp.send(state[:socket], io_msg)
    {:noreply, state}
  end

end
