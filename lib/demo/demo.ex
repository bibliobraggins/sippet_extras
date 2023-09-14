defmodule Demo do
  require Logger

  use Spigot.UserAgent
  def register(transaction) do
    Logger.debug(transaction.request |> to_string())
  end
end
