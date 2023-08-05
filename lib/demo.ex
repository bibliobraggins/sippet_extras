defmodule Spigot.TestRouter do
  use Spigot.Router, name: :test
  require Logger

  def register(msg, _key) do
    Logger.debug(to_string(msg))
    send_resp(msg, 200)
  end
end

defmodule Spigot.Test do
  def start, do: Spigot.start(name: :test, port: 5065, transport: :tcp, router: Spigot.TestRouter)
end
