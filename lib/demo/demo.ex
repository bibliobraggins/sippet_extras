defmodule Demo do
  require Logger

  use Spigot.UserAgent

  def receive_request(
        %Message{start_line: %RequestLine{method: :ack}} = _request,
        _spigot,
        nil
      ),
      do: :ok

  def receive_request(
        %Message{start_line: %RequestLine{method: :invite}} = request,
        spigot,
        _key
      ),
      do: send_message(spigot, Message.to_response(request, 501))

  def receive_request(request, spigot, _key) do
    response = Message.to_response(request, 200)

    send_message(spigot, response)
  end
end
