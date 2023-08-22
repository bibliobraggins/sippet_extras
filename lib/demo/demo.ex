defmodule Demo do
  use Spigot.UserAgent,
    name: :demo,
    clients: []

  require Logger

  def ack(msg, _key) do
    log(msg)
    send_resp(msg, 200)
  end

  def register(msg, _key) do
    log(msg)
    send_resp(msg, 200)
  end

  def invite(msg, _key) do
    log(msg)
    send_resp(msg, 488)
  end

  defp log(msg) do
    Logger.debug("#{__MODULE__}\nReceived:\n#{to_string(msg)}")
  end
end
