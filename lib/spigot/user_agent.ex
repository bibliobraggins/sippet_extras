defmodule Spigot.UserAgent do
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

  defmacro __using__(user_agent_options \\ nil) do
    @methods |> inspect()
    quote location: :keep do
      @behaviour Spigot.UserAgent
      import Spigot.UserAgent

      @moduledoc """
        Think of UserAgent as a container of logic that pertains to your requests and responses
        Spigot UserAgents do not construct or handle requests or responses directly.

        Instead, UserAgents are more something akin to a Plug or Plug Router.
        It's main job is orchestrate a request or responses passage through a network interface.
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


      if length(unquote(user_agent_options)) > 0 do
        ua_opts = unquote(user_agent_options)
        IO.inspect(ua_opts)
      end
    end
  end
end
