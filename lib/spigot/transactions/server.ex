defmodule Spigot.Transactions.Server do
  @moduledoc false

  alias Sippet.Message
  alias Sippet.Message.{RequestLine, StatusLine}
  alias Spigot.Transactions.Server.State, as: State

  def receive_request(server, %Message{start_line: %RequestLine{}} = request),
    do: GenStateMachine.cast(server, {:incoming_request, request})

  def send_response(server, %Message{start_line: %StatusLine{}} = response),
    do: GenStateMachine.cast(server, {:outgoing_response, response})

  def receive_error(server, reason),
    do: GenStateMachine.cast(server, {:error, reason})

  def terminate(server),
    do: GenStateMachine.cast(server, :terminate)

  defmacro __using__(opts) do
    quote location: :keep do
      use GenStateMachine, callback_mode: [:state_functions, :state_enter]

      alias Spigot.Transactions.Server.State

      require Logger

      def init(%State{key: key} = data) do
        Logger.debug("server transaction #{inspect(key)} started")

        initial_state = unquote(opts)[:initial_state]
        {:ok, initial_state, data}
      end

      defp send_response(response, %State{key: key, spigot: spigot} = data) do
        extras = data.extras |> Map.put(:last_response, response)
        data = %{data | extras: extras}
        Spigot.Router.send_transport_message(spigot, response, key)
        data
      end

      defp receive_request(request, %State{key: key, user_agent: user_agent, spigot: spigot}),
        do: Spigot.Router.to_ua(user_agent, :receive_request, [request, spigot, key])

      def shutdown(reason, %State{key: key, user_agent: user_agent, spigot: spigot} = data) do
        Logger.warning("server transaction #{inspect(key)} shutdown: #{reason}")

        Spigot.Router.to_ua(user_agent, :receive_error, [reason, spigot, key])

        {:stop, :shutdown, data}
      end

      def timeout(data),
        do: shutdown(:timeout, data)

      def reliable?(request, %State{spigot: spigot}),
        do: Spigot.reliable?(request)

      def unhandled_event(:cast, :terminate, %State{key: key} = data) do
        Logger.debug("server transaction #{inspect(key)} terminated")

        {:stop, :normal, data}
      end

      def unhandled_event(event_type, event_content, %State{key: key} = data) do
        Logger.error([
          "server transaction #{inspect(key)} got unhandled_event/3:",
          " #{inspect(event_type)}, #{inspect(event_content)}, #{inspect(data)}"
        ])

        {:stop, :shutdown, data}
      end

      def child_spec([%{key: server_key}, _] = args) do
        %{
          id: {__MODULE__, server_key},
          start: {__MODULE__, :start_link, [args]},
          restart: :transient
        }
      end

      def start_link([initial_data, opts]),
        do: GenStateMachine.start_link(__MODULE__, initial_data, opts)

      defoverridable init: 1,
                     send_response: 2,
                     receive_request: 2,
                     shutdown: 2,
                     timeout: 1,
                     unhandled_event: 3
    end
  end
end
