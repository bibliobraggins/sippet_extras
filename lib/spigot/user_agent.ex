defmodule Spigot.UserAgent do
  require Logger

  alias Sippet.Message, as: Msg
  alias Msg.RequestLine, as: Req
  alias Msg.StatusLine, as: Resp

  @type request :: %Msg{start_line: %Req{}}
  @type response :: %Msg{start_line: %Resp{}}

  defmacro __using__(options \\ []) do
    if is_list(clients = options[:clients]) and length(clients) > 0 do
      Spigot.UserAgent.Client.build_clients(clients)
    end

    quote do
      import Spigot.UserAgent

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
        do: raise("#{__MODULE__} receive_response/2 failed to handle: #{inspect(key)}")

      def receive_error(reason, key),
        do: raise("#{__MODULE__} receive_error/2 failed to handle: #{inspect(key)}")

      defp do_send_resp(%Msg{start_line: %Resp{}} = resp),
        do: Sippet.send(__MODULE__, resp)

      def send_resp(%Msg{start_line: %Resp{}} = resp),
        do: do_send_resp(resp)

      def send_resp(%Msg{start_line: %Req{}} = req, status),
        do: Msg.to_response(req, status) |> do_send_resp()

      def send_resp(%Msg{start_line: %Req{}} = req, status, reason) when is_binary(reason),
        do: Msg.to_response(req, status, reason) |> do_send_resp()

      use Supervisor

      def start_link(options) when is_list(options) do
        Supervisor.start_link(__MODULE__, options)
      end

      @impl true
      def init(options) do
        children = [
          {Registry,
           name: __MODULE__.ClientRegistry, keys: :unique, partitions: System.schedulers_online()},
          {DynamicSupervisor, strategy: :one_for_one, name: __MODULE__.ClientSupervisor}
        ]

        with {:ok, ua_sup} <- Supervisor.init(children, strategy: :one_for_one) do
          Sippet.register_core(__MODULE__, __MODULE__)
          {:ok, ua_sup}
        else
          reason ->
            raise("#{inspect(reason)}")
        end
      end

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

  ## build children here

  ## TODO: write out DSL for validation and SIP header/body manipulation
end
