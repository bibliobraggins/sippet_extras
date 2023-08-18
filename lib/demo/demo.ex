defmodule Spigot.Demo do
  require Logger

  @user_agent name: :my_service_1

  use Spigot.UserAgent

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
    Logger.debug("#{__MODULE__}|#{@user_agent[:name]} Received:\n#{to_string(msg)}")
  end
end
