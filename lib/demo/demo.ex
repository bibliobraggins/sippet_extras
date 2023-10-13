defmodule Demo do
  require Logger

  use Spigot.UserAgent

  def receive_request(%Message{start_line: %RequestLine{}} = request, spigot, _key) do
    response = Message.to_response(request, 200)

    Logger.info(to_string(request))

    send_message(spigot, response)

    :ok
  end
end
