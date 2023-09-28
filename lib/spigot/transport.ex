defmodule Spigot.Transport do
  require Logger
  import Spigot.TransportHelpers

  @callback build_options(options :: keyword()) ::
              {module(), list()} | {:error, term()}

  @callback init(options :: keyword()) ::
              {:ok, Types.socket()} | {:error, term()}

  @callback connect(binary(), :inet.port_number(), opts :: keyword()) ::
              {:ok, term()} | {:error, term()}

  @callback send_message(Types.message(), term(), keyword()) ::
              :ok | {:error, term()}

  @callback close(Types.socket()) ::
              :ok | {:error, term()}

  @optional_callbacks [
    connect: 3
  ]

  use GenServer

  def start_link(opts) do
    address = Keyword.get(opts, :address, "0.0.0.0")
    family = get_family(address)
    ip = get_ip(address, family)

    opts =
      opts
      |> Keyword.put_new(:ip, ip)
      |> Keyword.put_new(:family, family)

    {socket_module, opts} =
      case Keyword.fetch!(opts, :transport) do
        :udp ->
          Spigot.Transports.UDP.build_options(opts)

        :tcp ->
          Spigot.Transports.TCP.build_options(opts)

        :tls ->
          Spigot.Transports.TCP.build_options(opts)

        :ws ->
          Spigot.Transports.WS.build_options(opts)

        :wss ->
          Spigot.Transports.WS.build_options(opts)

        _ ->
          raise "must provide a supported transport option"
      end

    sockname = :"#{address}:#{opts[:port]}/#{opts[:transport]}"

    opts =
      opts
      |> Keyword.put(:address, address)
      |> Keyword.put(:socket_module, socket_module)
      |> Keyword.put(:sockname, sockname)

    GenServer.start_link(__MODULE__, opts, name: sockname)
  end

  @impl true
  def init(opts) do
    IO.inspect(opts)

    case opts[:socket_module].init(opts) do
      {:ok, sock} ->
        Logger.debug("#{inspect(sock)} :: #{inspect(opts)}")
        {:ok, opts |> Keyword.put(:socket, sock)}

      {:error, error} ->
        raise "couldn't start transport: #{inspect(error)} #{inspect(opts)}"
    end
  end

  @impl true
  def handle_info({from_host, from_port, msg}, state) do
    Logger.debug("got io message: #{inspect({from_host, from_port, Sippet.Message.parse!(msg)})}")
    {:noreply, state}
  end

  @impl true
  def terminate(:shutdown, opts) do
    "Shutting down transport: #{inspect(opts[:sockname])}" |> Logger.debug()

    opts[:socket_module].close(opts[:socket])

    exit(:shutdown)
  end
end
