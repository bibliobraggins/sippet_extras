defmodule Spigot.Transport do
  @callback build_options(options :: keyword()) :: {module(), list()} | {:error, term()}

  @callback listen(options :: keyword()) :: {:ok, Types.socket()} | {:error, term()}

  @callback connect(binary(), :inet.port_number(), opts :: keyword()) ::
              {:ok, term()} | {:error, term()}

  @callback send_message(Types.message(), term(), keyword()) :: :ok | {:error, term()}

  @callback close(Types.socket()) :: :ok | {:error, term()}

  @callback recv(Types.socket(), bytes :: non_neg_integer(), timeout()) ::
              {:ok, binary()} | {:error, term()}

  @callback controlling_process(Types.socket(), pid()) :: :ok | {:error, term()}

  @callback setopts(Types.socket(), opts :: keyword()) :: :ok | {:error, term()}

  @callback getopts(Types.socket(), opts :: keyword()) ::
              {:ok, opts :: keyword()} | {:error, term()}

  @optional_callbacks [
    connect: 3,
    setopts: 2,
    getopts: 2,
    controlling_process: 2,
    recv: 3
  ]

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, build(opts))
  end

  def init(opts) do
    opts[:transport].listen()
  end

  defp build(opts) do
    address = Keyword.get(opts, :address, "0.0.0.0")

    family = get_family(address)

    ip =
      case resolve_name(opts[:address], family) do
        {:ok, ip} when is_tuple(ip) ->
          ip

        {:error, reason} ->
          raise ArgumentError,
                ":address contains an invalid IP or DNS name, got: #{inspect(reason)}"
      end

    port = Keyword.get(opts, :port, 5060)

    {transport_module, transport_options} =
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
          raise "must provide a supported transport"
      end

    sockname = :"#{:inet.ntoa(ip)}:#{port}/#{opts[:transport]}"

    opts
    |> Keyword.put_new(:address, address)
    |> Keyword.put_new(:family, family)
    |> Keyword.put_new(:port, port)
    |> Keyword.put_new(:transport_module, transport_module)
    |> Keyword.put_new(:transport_options, transport_options)
    |> Keyword.put_new(:sockname, sockname)
  end

  def get_family(host) when is_binary(host),
    do: host |> to_charlist() |> get_family()
  def get_family(host) when is_list(host) do
    case :inet.parse_address(host) do
      {:ok, host} ->
        get_family(host)

      error ->
        error
    end
  end
  def get_family({_, _, _, _}), do: :inet
  def get_family({_, _, _, _, _, _, _}), do: :inet6

  @spec resolve_name(binary, :inet | :inet6 | :local) ::
          {:error, :eafnosupport | :einval | :nxdomain}
          | {:ok,
             {byte, byte, byte, byte}
             | {char, char, char, char, char, char, char, char}}
  def resolve_name(host, family) do
    host
    |> String.to_charlist()
    |> :inet.getaddr(family)
  end
end
