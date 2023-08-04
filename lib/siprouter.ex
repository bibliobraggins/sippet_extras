defmodule SipRouter do
  alias Sippet.Message, as: MSG
  alias MSG.RequestLine, as: REQ
  # alias MSG.StatusLine, as: RESP

  # "ACK", "BYE", "CANCEL", "INFO", "INVITE", "MESSAGE", "NOTIFY", "OPTIONS","PRACK", "PUBLISH", "PULL", "PUSH", "REFER", "REGISTER", "STORE", "SUBSCRIBE","UPDATE"
  @methods Enum.into(Sippet.Message.known_methods(), [], fn method ->
             String.downcase(method) |> String.to_existing_atom()
           end)

  defmacro __using__(opts) do
    quote location: :keep do
      import SipRouter
      use Sippet.Core

      def start(sippet) do
        Sippet.register_core(sippet, unquote(opts[:name]))
      end

      def ack(_, _), do: :ok
      def bye(_, _), do: :ok
      def cancel(_, _), do: :ok
      def info(_, _), do: :ok
      def invite(_, _), do: :ok
      def message(_, _), do: :ok
      def notify(_, _), do: :ok
      def options(_, _), do: :ok
      def prack(_, _), do: :ok
      def publish(_, _), do: :ok
      def pull(_, _), do: :ok
      def push(_, _), do: :ok
      def refer(_, _), do: :ok
      def register(_, _), do: :ok
      def store(_, _), do: :ok
      def subscribe(_, _), do: :ok
      def update(_, _), do: :ok

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

      defoverridable start: 1,
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
