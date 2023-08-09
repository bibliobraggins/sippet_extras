defmodule Spigot.Transports.WS.Server do
  require Logger

  def init(options) do
    Logger.debug(inspect(options))
    {:ok, options}
  end

  def handle_in({data, [opcode: _any]}, state) do
    peer = state[:peer]
    Sippet.Router.handle_transport_message(:test, data, {:ws, peer.address, peer.port})

    {:reply, :ok, {:text, data}, state}
  end

  def terminate(any, state) do
    Logger.debug(inspect(any))
    {:ok, state}
  end
end
