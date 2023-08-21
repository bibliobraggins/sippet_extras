defmodule Spigot.Demo do
  @user_agent server: [name: :demo],
              client: []

  use Spigot.UserAgent

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
    Logger.debug("#{__MODULE__}|#{inspect(@user_agent[:name])} Received:\n#{to_string(msg)}")
  end
end
