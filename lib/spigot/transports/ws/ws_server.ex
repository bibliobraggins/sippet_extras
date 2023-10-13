defmodule Spigot.Transports.WS.Server do
  require Logger

  alias Spigot.Connections

  def init(state) do
    peer = state[:peer]

    Connections.connect(state[:connections], {peer.address, peer.port}, self())

    {:ok, state}
  end

  @keepalive <<13, 10, 13, 10>>
  def handle_in({@keepalive, _}, state), do: {:noreply, state}
  @exit_code <<255, 244, 255, 253, 6>>
  def handle_in({@exit_code, _}, state), do: {:close, state}

  # we may need to wrap a second handler depending on how complicated the websocket
  # opcode handling needs to be

  def handle_in({data, [opcode: _any]}, state) do
    peer = state[:peer]

    Spigot.Router.handle_transport_message(
      data,
      {:ws, peer.address, peer.port},
      state[:user_agent],
      state[:spigot]
    )

    {:ok, state}
  end

  def handle_info({:send_message, msg}, state) do
    io_msg = Sippet.Message.to_iodata(msg)

    {:push, {:text, io_msg}, state}
  end

  def terminate(_any, state) do
    {:ok, state}
  end
end
