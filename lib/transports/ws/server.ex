defmodule Spigot.Transports.WS.Server do
  require Logger

  def init(options) do
    {:ok, options}
  end

  def handle_in({data, [opcode: :text]}, state) do
    Logger.debug(inspect(to_string(data)))

    {:reply, :ok, {:text, "pong"}, state}
  end

  def terminate(:timeout, state) do
    {:ok, state}
  end

  def terminate(any, state) do
    Logger.debug(inspect(any))
    {:ok, state}
  end
end
