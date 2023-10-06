defmodule Demo do
  require Logger

  use Spigot.UserAgent

  def receive_request(%Message{start_line: %RequestLine{method: method}} = request, spigot, _key) do
    if method == :register do
      response =
        Message.to_response(request, 200)

      send_message(spigot, response)
    end

    :ok
  end
end
