defmodule Spigot.UserAgent do
  # alias Sippet.Message, as: MSG
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

  defmacro __using__(_) do
    @methods |> inspect()
    quote location: :keep do
      @behaviour Spigot.UserAgent
      import Spigot.UserAgent

      use Supervisor

      def start_link(options) when is_list(options) do
        user_agent = __MODULE__

        transport_module =
          case Keyword.fetch!(options, :transport) do
            :udp ->
              Spigot.Transports.UDP

            :tcp ->
              Spigot.Transports.TCP

            :tls ->
              Spigot.Transports.TCP

            :ws ->
              Spigot.Transports.WS

            :wss ->
              Spigot.Transports.WS

            _ ->
              raise "must provide a supported transport"
          end

      transport_options =
        Keyword.get(options, :transport_options, [])
        |> Keyword.put_new(:user_agent, __MODULE__)

      options =
        Keyword.delete(options, :transport)
        |> Keyword.put_new(:transport_module, transport_module)
        |> Keyword.put_new(:transport_options, transport_options)

        GenServer.start_link(__MODULE__, options, name: __MODULE__)
      end

      @impl true
      def init(options) do

        children = [
          {Registry, name: __MODULE__.ClientRegistry, keys: :unique, partitions: System.schedulers_online()},
          {DynamicSupervisor, strategy: :one_for_one, name: __MODULE__.ClientSupervisor}
        ]

        with {:ok, transport_pid} <- options[:transport_module].start_link(options[:transport_options]),
              {:ok, ua_sup} <- Supervisor.init(children, strategy: :one_for_one) do

          unless is_nil(options[:clients]) do
            Enum.into(options[:clients], [], fn {method, opts} -> {__MODULE__, method, opts} end)
            |> Logger.debug()
          end

          {:ok, Keyword.put_new(options, :transport, transport_pid)}
        else
          reason ->
            IO.inspect(reason)
        end
      end

      def send_msg(msg), do: GenServer.cast(__MODULE__, {:send_msg, msg})

      def start_client(method, options),
        do: Spigot.UserAgent.Client.start_link({__MODULE__, method, options})

      @impl Spigot.UserAgent
      def handle_request(request),
        do: raise("Please define a request handler in #{__MODULE__}")

      @impl Spigot.UserAgent
      def handle_response(response),
        do: raise("Please define a response handler in #{__MODULE__}")

    end
  end
end
