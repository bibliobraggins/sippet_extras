defmodule Spigot.UserAgent do
  alias Sippet.Message, as: Msg
  alias Msg.RequestLine, as: Req
  alias Msg.StatusLine, as: Resp

  def server() do
    quote location: :keep do
      defp do_send(%Msg{start_line: %Resp{}} = resp),
        do: Sippet.send(@user_agent[:config][:name], resp)

      def send_resp(%Msg{start_line: %Resp{}} = resp), do: do_send(resp)

      def send_resp(%Msg{start_line: %Req{}} = req, status),
        do: Msg.to_response(req, status) |> do_send()

      def send_resp(%Msg{start_line: %Req{}} = req, status, reason) when is_binary(reason),
        do: Msg.to_response(req, status, reason) |> do_send()

      defp handle_undefined(%Msg{start_line: %Req{method: method}} = req), do: send_resp(req, 501)

      def invite(%Msg{start_line: %Req{}} = req, _), do: &handle_undefined/1
      def ack(%Msg{start_line: %Req{}} = req, _), do: &handle_undefined/1
      def bye(%Msg{start_line: %Req{}} = req, _), do: &handle_undefined/1
      def cancel(%Msg{start_line: %Req{}} = req, _), do: &handle_undefined/1
      def refer(%Msg{start_line: %Req{}} = req, _), do: &handle_undefined/1
      def register(%Msg{start_line: %Req{}} = req, _), do: &handle_undefined/1
      def subscribe(%Msg{start_line: %Req{}} = req, _), do: &handle_undefined/1
      def notify(%Msg{start_line: %Req{}} = req, _), do: &handle_undefined/1
      def options(%Msg{start_line: %Req{}} = req, _), do: &handle_undefined/1
      def info(%Msg{start_line: %Req{}} = req, _), do: &handle_undefined/1
      def message(%Msg{start_line: %Req{}} = req, _), do: &handle_undefined/1
      def prack(%Msg{start_line: %Req{}} = req, _), do: &handle_undefined/1
      def publish(%Msg{start_line: %Req{}} = req, _), do: &handle_undefined/1
      def pull(%Msg{start_line: %Req{}} = req, _), do: &handle_undefined/1
      def push(%Msg{start_line: %Req{}} = req, _), do: &handle_undefined/1
      def store(%Msg{start_line: %Req{}} = req, _), do: &handle_undefined/1
      def update(%Msg{start_line: %Req{}} = req, _), do: &handle_undefined/1

      @doc false
      def receive_request(%Msg{start_line: %Req{method: method}} = incoming_request, key),
        do: apply(__MODULE__, method, [incoming_request, key])

      def receive_response(response, client_key),
        do: raise("attempted to cal Router but no receive_response clause matched")

      @doc false
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

  defmacro __using__(_config) do
    server()
  end

  ## TODO: write out DSL for validation and SIP header/body manipulation
end
