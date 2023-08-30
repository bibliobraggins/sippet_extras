defmodule Spigot.UA do
  require Logger

  alias Sippet.Message, as: Msg
  alias Msg.RequestLine, as: Req
  alias Msg.StatusLine, as: Resp

  @type request :: %Msg{start_line: %Req{}}
  @type response :: %Msg{start_line: %Resp{}}

  @methods Enum.each(
             Msg.known_methods(),
             fn method ->
               method
               |> String.downcase()
               |> String.to_existing_atom()
             end
           )

  def extract_guards({:when, _, [_, guards]}), do: guards

  defmacro __using__(_) do
    quote do
      import Spigot.UserAgent

      def receive_request(%Msg{start_line: %Req{method: method}} = request, key) do
        if Enum.any?(unquote(@methods), fn i -> method == i end) do
          apply(__MODULE__, method, [request, key])
        else
          send_resp(request, 501)
        end
      end

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
    end
  end

  ## build children here

  ## TODO: write out DSL for validation and SIP header/body manipulation
end
