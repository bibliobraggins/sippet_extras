defmodule Spigot.UserAgent do
  #alias Sippet.Message, as: MSG
  alias Sippet.Message
  alias Spigot.Types

  @callback handle_request(Types.request()) :: Types.response()

  @callback handle_response(Types.response()) :: :ok | {:error, term()}

  @methods Enum.each(
             Message.known_methods(),
             fn method ->
               method
               |> String.downcase()
               |> String.to_existing_atom()
             end
           )

  defmacro __using__(_options) do
    quote do
      @behaviour Spigot.UserAgent
      import Spigot.UserAgent

      @methods unquote(@methods)

      @impl Spigot.UserAgent
      def handle_request(request) do
        raise "Please define a request handler in #{__MODULE__}"
      end

      @impl Spigot.UserAgent
      def handle_response(response) do
        raise "Please define a response handler in #{__MODULE__}"
      end
    end
  end
end
