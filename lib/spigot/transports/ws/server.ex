defmodule Spigot.Transports.WS.Server do
  require Logger

  alias Spigot.Transports.WS, as: WS

  @keepalive <<13,10,13,10>>
  @exit_code <<255,244,255,253,6>>

  def init(options) do
    Logger.debug(options)
    WS.connect(:demo_connections, options[:peer], self())
    {:ok, options}
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
    {:ok, state}
  end
end
