defmodule Demo do
  use Spigot.UserAgent,
    name: :demo,
    clients: [
      {:register, "sip:100@127.0.0.1", username: "demo_spaghet", password: "92cb159da"},
    ]

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
