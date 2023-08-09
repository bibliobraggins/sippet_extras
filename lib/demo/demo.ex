defmodule Spigot.Demo do
  require Logger
  use Spigot.UserAgent, name: :enp2s0

  def ack(msg, _key) do
    log(msg)
  end

  def register(msg, _key) do
    log(msg)
    send_resp(msg, 200)
  end

  defp log(msg) do
    Logger.debug("Received:\n#{to_string(msg)}")
  end
end
