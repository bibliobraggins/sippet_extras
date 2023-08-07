defmodule Spigot.Demo do
  require Logger
  use Spigot.UserAgent, name: :demo_agent

  def ack(msg, _key) do
    send_resp(msg, 200)
  end
  def register(msg, _key) do
    send_resp(msg, 200)
  end

end
