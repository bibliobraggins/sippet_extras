defmodule Demo do
  require Logger

  use Spigot.UserAgent

  def receive_request(request, _key) do
    Logger.debug(request |> to_string())
  end
end
