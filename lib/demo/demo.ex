defmodule Demo do
  require Logger

  use Spigot.UserAgent

  def register(transaction) do
    transaction
    |> Logger.info()
  end
end
