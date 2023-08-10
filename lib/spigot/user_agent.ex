defmodule Spigot.UserAgent do
  alias Sippet.Message, as: Msg
  alias Msg.RequestLine, as: Req
  alias Msg.StatusLine, as: Resp

  defmacro __using__(options) do
    quote location: :keep do
      alias Spigot.UserAgent.Utils
      import Spigot.UserAgent
      use Sippet.Core

      defp do_send(%Msg{start_line: %Resp{}} = resp),
        do: Sippet.send(unquote(options[:name]), resp)

      def send_resp(%Msg{start_line: %Resp{}} = resp), do: do_send(resp)

      def send_resp(%Msg{start_line: %Req{}} = req, status),
        do: Msg.to_response(req, status) |> do_send()

      def send_resp(%Msg{start_line: %Req{}} = req, status, reason) when is_binary(reason),
        do: Msg.to_response(req, status, reason) |> do_send()

      def ack(%Msg{start_line: %Req{}}, _),
        do: raise("attempted to call ack/2 in #{inspect(__MODULE__)}")

      def bye(%Msg{start_line: %Req{}}, _),
        do: raise("attempted to call ack/2 in #{inspect(__MODULE__)}")

      def cancel(%Msg{start_line: %Req{}}, _),
        do: raise("attempted to call ack/2 in #{inspect(__MODULE__)}")

      def info(%Msg{start_line: %Req{}}, _),
        do: raise("attempted to call ack/2 in #{inspect(__MODULE__)}")

      def invite(%Msg{start_line: %Req{}}, _),
        do: raise("attempted to call ack/2 in #{inspect(__MODULE__)}")

      def message(%Msg{start_line: %Req{}}, _),
        do: raise("attempted to call ack/2 in #{inspect(__MODULE__)}")

      def notify(%Msg{start_line: %Req{}}, _),
        do: raise("attempted to call ack/2 in #{inspect(__MODULE__)}")

      def options(%Msg{start_line: %Req{}}, _),
        do: raise("attempted to call ack/2 in #{inspect(__MODULE__)}")

      def prack(%Msg{start_line: %Req{}}, _),
        do: raise("attempted to call ack/2 in #{inspect(__MODULE__)}")

      def publish(%Msg{start_line: %Req{}}, _),
        do: raise("attempted to call ack/2 in #{inspect(__MODULE__)}")

      def pull(%Msg{start_line: %Req{}}, _),
        do: raise("attempted to call ack/2 in #{inspect(__MODULE__)}")

      def push(%Msg{start_line: %Req{}}, _),
        do: raise("attempted to call ack/2 in #{inspect(__MODULE__)}")

      def refer(%Msg{start_line: %Req{}}, _),
        do: raise("attempted to call ack/2 in #{inspect(__MODULE__)}")

      def register(%Msg{start_line: %Req{}}, _),
        do: raise("attempted to call ack/2 in #{inspect(__MODULE__)}")

      def store(%Msg{start_line: %Req{}}, _),
        do: raise("attempted to call ack/2 in #{inspect(__MODULE__)}")

      def subscribe(%Msg{start_line: %Req{}}, _),
        do: raise("attempted to call ack/2 in #{inspect(__MODULE__)}")

      def update(%Msg{start_line: %Req{}}, _),
        do: raise("attempted to call ack/2 in #{inspect(__MODULE__)}")

      @doc false
      def receive_request(%Msg{start_line: %Req{}} = incoming_request, key) do
        method = incoming_request.start_line.method

        if Enum.member?(Utils.methods(), method) == true do
          apply(__MODULE__, method, [incoming_request, key])
        end
      end

      def receive_response(response, client_key),
        do: raise("attempted to call Router but no receive_response clause matched")

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

  ## TODO: write out DSL for validation and SIP header/body manipulation
end
