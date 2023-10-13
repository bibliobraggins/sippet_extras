defmodule Demo do
  require Logger

  use Spigot.UserAgent

  def receive_request(%Message{start_line: %RequestLine{}} = request, spigot, _key) do
    response =
      Message.to_response(request, 200)

      Logger.debug(request.start_line |> to_string)
      Logger.debug(response.start_line |> to_string)

    send_message(spigot, response)
  end
end
