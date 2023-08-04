defmodule Test.SIPRouter do
  use SipRouter, name: __MODULE__

  alias Sippet.Message, as: MSG

  require Logger

  def register(msg, key) do
    log(msg, key)

    Sippet.send(:test, MSG.to_response(msg, 200))
  end

  def subscribe(msg, key) do
    log(msg, key)
  end

  def log(msg, key) do
    Logger.debug("#{inspect(key)}\n#{to_string(msg)}")
  end
end
