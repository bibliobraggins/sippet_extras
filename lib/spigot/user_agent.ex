defmodule Spigot.UserAgent do
  alias Sippet.Message
  alias Message.{RequestLine, StatusLine}
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

  defmacro __using__(options) do
    @methods |> inspect()

    options |> IO.inspect()

    quote location: :keep do
      alias Sippet.Message
      alias Message.{RequestLine, StatusLine}

      @behaviour Spigot.UserAgent
      import Spigot.UserAgent

      @moduledoc """
        Think of UserAgent as a container of logic that pertains to your requests and responses.
        It's main job is orchestrate a request or responses passage through a network interface.
        In more sophisticated implementations, multiple useragents could pass messages to each other
        to facilitate multiple network distributed operations across a system.
      """

      @impl Spigot.UserAgent
      def handle_request(request),
        do: raise("No request handler in #{__MODULE__}")

      @impl Spigot.UserAgent
      def handle_response(response),
        do: raise("No response handler in #{__MODULE__}")

      # When a request comes in to a UserAgent, A process is spawned to construct the message
      # and handle responses (or subsequent transactions) accordingly.
      # the process is will be named according to it's URI, in a registry specific to the UserAgent scope

      def send_message(spigot, message) do
        unless Message.valid?(message) do
          raise ArgumentError, "expected :message argument to be a valid SIP message"
        end

        Spigot.send(__MODULE__, spigot, message)
      end
    end
  end
end
