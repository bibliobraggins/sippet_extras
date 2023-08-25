defmodule UserAgent do
  use Sippet.Core

  require Logger

  defmacrop client(options) do
    quote do
      unquote(options[:name])
    end
  end

  # [transport: transport, port: port, server: ]
  defmacro __using__(:client) do
    quote do
      import unquote(__MODULE__)

      def receive_request(request, _client_key) do
        request
        |> inspect()
        |> Logger.debug()
      end

      def receive_response(response, _client_key) do
        response
        |> inspect()
        |> Logger.debug()
      end
    end
  end
end
