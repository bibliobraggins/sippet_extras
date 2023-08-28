defmodule Spigot.Transports.WS.Server do
  require Logger

  alias Spigot.Transports.WS, as: WS

  @keepalive <<13, 10, 13, 10>>
  @exit_code <<255, 244, 255, 253, 6>>

  def init(state) do
    Logger.debug(state)
    WS.connect(Demo, state[:peer], self())
    {:ok, state}
  end

  def handle_in({@keepalive, _}, state), do: {:noreply, state}
  def handle_in({@exit_code, _}, state), do: {:close, state}

  def handle_in({data, [opcode: _any]}, state) do
    peer = state[:peer]
    Sippet.Router.handle_transport_message(:test, data, {:ws, peer.address, peer.port})

    {:reply, :ok, {:text, data}, state}
  end

  def terminate(any, state) do
    Logger.debug(inspect(any))
    WS.disconnect(Demo, state[:peer])
    {:ok, state}
  end
end
