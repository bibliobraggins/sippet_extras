defmodule Spigot.Router do
  alias Sippet.Message, as: MSG
  alias MSG.RequestLine, as: REQ
  # alias MSG.StatusLine, as: RESP

  # "ACK", "BYE", "CANCEL", "INFO", "INVITE", "MESSAGE", "NOTIFY", "OPTIONS","PRACK", "PUBLISH", "PULL", "PUSH", "REFER", "REGISTER", "STORE", "SUBSCRIBE","UPDATE"
  @methods Enum.into(Sippet.Message.known_methods(), [], fn method ->
             String.downcase(method) |> String.to_existing_atom()
           end)

  defmacro __using__(opts) do
    quote location: :keep do
      import Spigot.Router
      use Sippet.Core

      def send_resp(%MSG{start_line: %REQ{}} = req, status_code), do: Sippet.send(unquote(opts[:name]), MSG.to_response(req, status_code))
      def send_resp(%MSG{start_line: %REQ{}} = req, status_code, reason) when is_binary(reason) do
        Sippet.send(unquote(opts[:name]), MSG.to_response(req, status_code, reason))
      end

      def ack(_, _), do: raise "attempted to call ack/2 in #{inspect(__MODULE__)}"
      def bye(_, _), do: raise "attempted to call ack/2 in #{inspect(__MODULE__)}"
      def cancel(_, _), do: raise "attempted to call ack/2 in #{inspect(__MODULE__)}"
      def info(_, _), do: raise "attempted to call ack/2 in #{inspect(__MODULE__)}"
      def invite(_, _), do: raise "attempted to call ack/2 in #{inspect(__MODULE__)}"
      def message(_, _), do: raise "attempted to call ack/2 in #{inspect(__MODULE__)}"
      def notify(_, _), do: raise "attempted to call ack/2 in #{inspect(__MODULE__)}"
      def options(_, _), do: raise "attempted to call ack/2 in #{inspect(__MODULE__)}"
      def prack(_, _), do: raise "attempted to call ack/2 in #{inspect(__MODULE__)}"
      def publish(_, _), do: raise "attempted to call ack/2 in #{inspect(__MODULE__)}"
      def pull(_, _), do: raise "attempted to call ack/2 in #{inspect(__MODULE__)}"
      def push(_, _), do: raise "attempted to call ack/2 in #{inspect(__MODULE__)}"
      def refer(_, _), do: raise "attempted to call ack/2 in #{inspect(__MODULE__)}"
      def register(_, _), do: raise "attempted to call ack/2 in #{inspect(__MODULE__)}"
      def store(_, _), do: raise "attempted to call ack/2 in #{inspect(__MODULE__)}"
      def subscribe(_, _), do: raise "attempted to call ack/2 in #{inspect(__MODULE__)}"
      def update(_, _), do: raise "attempted to call ack/2 in #{inspect(__MODULE__)}"

      @doc false
      def receive_request(%MSG{start_line: %REQ{}} = msg, key) do
        method = msg.start_line.method

        if Enum.member?(unquote(@methods), method) == true do
          Kernel.apply(__MODULE__, method, [msg, key])
        end
      end

      @doc false
      def receive_response(incoming_response, client_key) do
        raise "attempted to call Core but no receive_response/2 was provided"
      end

      @doc false
      def receive_error(reason, client_or_server_key) do
        raise "attempted to call Core but no receive_error/2 was provided"
      end

      defoverridable ack: 2,
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
