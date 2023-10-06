defmodule Spigot.Transports.WS.Server do
  require Logger

  def init(state) do
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
      state[:sockname]
    )

    ## if we can parse the io message, we should begin a transaction,
    ## pass it into state, then delegate to to a transaction handler module
    ## that will be responsible for passing it up to the "user_agent"

    # {:reply, :ok, {:text, "OK"}, state}
    {:ok, state}
  end

  def terminate(_any, state) do
    {:ok, state}
  end
end
