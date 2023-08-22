defmodule Spigot.UserAgent do
  alias Sippet.Message, as: Msg
  alias Msg.RequestLine, as: Req
  alias Msg.StatusLine, as: Resp

  @type request :: %Msg{start_line: %Req{}}
  @type response :: %Msg{start_line: %Resp{}}

  defmacro __using__(options) do
    ## build children here

    quote location: :keep do
      if is_list(clients = unquote(options[:clients])) && length(clients) > 0 do
        def start_link() do
          Enum.each(unquote(options[:clients]), fn x -> IO.inspect(x) end)
        end
      end

      defp do_send_resp(%Msg{start_line: %Resp{}} = resp),
        do: Sippet.send(unquote(options[:name]), resp)

      def send_resp(%Msg{start_line: %Resp{}} = resp), do: do_send_resp(resp)

      def send_resp(%Msg{start_line: %Req{}} = req, status),
        do: Msg.to_response(req, status) |> do_send_resp()

      def send_resp(%Msg{start_line: %Req{}} = req, status, reason) when is_binary(reason),
        do: Msg.to_response(req, status, reason) |> do_send_resp()

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

      def receive_response(response, client_key),
        do: raise("attempted to cal Router but no receive_response clause matched")

      def receive_error(reason, client_or_server_key),
        do: raise("TODO: attempted to call Router but no receive_error/2 clause matched")

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
