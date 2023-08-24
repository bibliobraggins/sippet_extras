defmodule Spigot.UserAgent do
  alias Sippet.Message, as: Msg
  alias Msg.RequestLine, as: Req
  alias Msg.StatusLine, as: Resp

  require Logger

  @type request :: %Msg{start_line: %Req{}}
  @type response :: %Msg{start_line: %Resp{}}

  defmacro __using__(options) do
    ## build children here

    quote do
      import Spigot.UserAgent

        @moduledoc """
          we must at least have a method and uri available to initially construct a message

          all other parameters should be provided in the options list:
            body: an expression that yields a UTF8 string of a body
              - examples:
                - SDP media descriptions (RFC3261)
                - BLF XML requests (RFC3265)
                - SMS chardata (SIP SIMPLE Messages)
        """

      defmodule __MODULE__.ClientSupervisor do
        use DynamicSupervisor

        def start_link(_), do: start_link()

        def start_link() do
          DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
        end

        def init(_) do
          DynamicSupervisor.init(strategy: :one_for_one)
        end

        def start_child() do

        end

        if is_list(clients = unquote(options[:clients])) and length(clients) > 0 do
          Spigot.UserAgent.Client.build_clients(clients)
        end
      end

      def invite(%Msg{start_line: %Req{}} = req, _), do: send_resp(req, 501)
      def ack(%Msg{start_line: %Req{}} = req, _), do: send_resp(req, 501)
      def bye(%Msg{start_line: %Req{}} = req, _), do: send_resp(req, 501)
      def cancel(%Msg{start_line: %Req{}} = req, _), do: send_resp(req, 501)
      def refer(%Msg{start_line: %Req{}} = req, _), do: send_resp(req, 501)
      def register(%Msg{start_line: %Req{}} = req, _), do: send_resp(req, 501)
      def subscribe(%Msg{start_line: %Req{}} = req, _), do: send_resp(req, 501)
      def notify(%Msg{start_line: %Req{}} = req, _), do: send_resp(req, 501)
      def options(%Msg{start_line: %Req{}} = req, _), do: send_resp(req, 501)
      def info(%Msg{start_line: %Req{}} = req, _), do: send_resp(req, 501)
      def message(%Msg{start_line: %Req{}} = req, _), do: send_resp(req, 501)
      def prack(%Msg{start_line: %Req{}} = req, _), do: send_resp(req, 501)
      def publish(%Msg{start_line: %Req{}} = req, _), do: send_resp(req, 501)
      def pull(%Msg{start_line: %Req{}} = req, _), do: send_resp(req, 501)
      def push(%Msg{start_line: %Req{}} = req, _), do: send_resp(req, 501)
      def store(%Msg{start_line: %Req{}} = req, _), do: send_resp(req, 501)
      def update(%Msg{start_line: %Req{}} = req, _), do: send_resp(req, 501)

      @doc "this is a minimal helper to allow declarative request handling"
      def receive_request(%Msg{start_line: %Req{method: method}} = incoming_request, key),
        do: apply(__MODULE__, method, [incoming_request, key])

      def receive_response(response, key),
        do:
          raise(
            "UserAgent:#{__MODULE__} receive_response/2 failed to handle: #{inspect(key)}"
          )

      def receive_error(reason, key),
        do:
          raise(
            "UserAgent:#{__MODULE__} receive_error/2 failed to handle: #{inspect(key)}"
          )

      defp do_send_resp(%Msg{start_line: %Resp{}} = resp),
        do: Sippet.send(unquote(options[:name]), resp)

      def send_resp(%Msg{start_line: %Resp{}} = resp),
        do: do_send_resp(resp)

      def send_resp(%Msg{start_line: %Req{}} = req, status),
        do: Msg.to_response(req, status) |> do_send_resp()

      def send_resp(%Msg{start_line: %Req{}} = req, status, reason) when is_binary(reason),
        do: Msg.to_response(req, status, reason) |> do_send_resp()

      defoverridable receive_request: 2,
                     receive_response: 2,
                     receive_error: 2,
                     ack: 2,
                     bye: 2,
                     cancel: 2,
                     info: 2,
                     invite: 2,
                     message: 2,
                     notify: 2,
                     options: 2,
                     prack: 2,
                     publish: 2,
                     pull: 2,
                     push: 2,
                     refer: 2,
                     register: 2,
                     store: 2,
                     subscribe: 2,
                     update: 2
    end
  end

  ## TODO: write out DSL for validation and SIP header/body manipulation
end
