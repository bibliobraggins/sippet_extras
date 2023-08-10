defmodule Spigot.Transports.TCP.Client do
  use GenServer
  require Logger

  alias Sippet.Message, as: Msg
  import Spigot.Transports.TCP

  @type option :: :registry | :timeout | :peer | :socket | :start_message | :retries
  @type options :: [option]

  @enforce_keys [
    :registry,
    :timeout,
    :peer,
    :socket,
    :start_message,
    :retries
  ]

  defstruct @enforce_keys
  @type t :: %__MODULE__{}

  @spec start_link(keyword) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(options) do
    registry =
      case Keyword.fetch(options, :registry) do
        {:ok, registry} when is_atom(registry) ->
          registry

        _ ->
          raise "no registry pid provided to #{inspect(__MODULE__)}, #{inspect(self())}"
      end

    peer =
      case Keyword.fetch(options, :peer) do
        {:ok, {addr, port}} ->
          {addr, port}

        _ ->
          raise "no {peer_addr, peer_port} data provided to #{inspect(__MODULE__)}, #{inspect(self())}"
      end

    {address, family} =
      case Keyword.fetch(options, :address) do
        {:ok, {address, family}} when family in [:inet, :inet6] and is_binary(address) ->
          {address, family}

        {:ok, address} when is_binary(address) ->
          {address, :inet}

        {:ok, other} ->
          raise ArgumentError,
                "expected :address to be an address or {address, family} tuple, got: " <>
                  "#{inspect(other)}"

        :error ->
          {"0.0.0.0", :inet}
      end

    timeout =
      case Keyword.fetch(options, :timeout) do
        {:ok, timeout} when is_integer(timeout) ->
          timeout

        _ ->
          10_000
      end

    ip =
      case resolve_name(address, family) do
        {:ok, ip} ->
          ip

        {:error, reason} ->
          raise ArgumentError,
                ":address contains an invalid IP or DNS name, got: #{inspect(reason)}"
      end

    # initial message to transmit on behalf of downstream client
    start_message =
      with {:ok, start_message} <- Keyword.fetch(options, :start_message) do
        # true <- Msg.valid?(start_message) do
        start_message
      else
        _ ->
          Logger.error("initial message must be a valid SIP message: assuming this is a test")
      end

    options = [
      ip: ip,
      registry: registry,
      family: family,
      peer: peer,
      timeout: timeout,
      start_message: start_message,
      retries: 5
    ]

    GenServer.start_link(__MODULE__, options)
  end

  @impl true
  @spec init(options()) :: {:ok, :connect, {:continue, options}}
  def init(options) do
    {:ok, :connect, {:continue, options}}
  end

  @impl true
  @spec handle_continue(keyword, :connect) ::
          {:noreply, struct} | {:noreply, :connect, {:continue, options()}}
  def handle_continue(options, :connect) do
    {addr, port} = options[:peer]

    case :gen_tcp.connect(
           addr,
           port,
           [:binary, {:active, true}, {:packet, :raw}, {:ip, options[:ip]}, options[:family]],
           options[:timeout]
         ) do
      {:ok, socket} ->
        state = struct(__MODULE__, Keyword.put(options, :socket, socket))

        :gen_tcp.send(socket, options[:start_message]) |> inspect() |> Logger.debug()

        {:noreply, state}

      {:error, reason} ->
        Logger.error(
          "could not connect to #{inspect(addr)}:#{inspect(port)} :: #{inspect(reason)}"
        )

        Process.sleep(5_000)
        {:noreply, :connect, {:continue, Keyword.put(options, :retries, options[:retries] - 1)}}
    end
  end

  @impl true
  def handle_info({:send_message, "\r\n\r\n" = msg}, state) do
    :gen_tcp.send(state.socket, msg) |> inspect() |> Logger.debug()

    {:noreply, {state.socket, state}}
  end

  @impl true
  def handle_info({:send_message, %Msg{} = msg}, state) do
    with io_msg <- Msg.to_iodata(msg) do
      Logger.debug("Sending:\n#{to_string(msg)}")
      :gen_tcp.send(state.socket, io_msg)
    else
      error ->
        Logger.error("Could not change message to io list. reason: #{inspect(error)}")
    end

    {:noreply, {state.socket, state}}
  end

  @impl true
  def handle_info({:tcp, socket, data}, state) do
    Logger.debug("#{inspect(socket)} recevied raw: #{inspect(data)}")

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, socket}, state) do
    Logger.debug("#{inspect(socket)} :: #{inspect(self())} closed")

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_error, socket, reason}, state) do
    Logger.debug("#{inspect(socket)} recevied error: #{inspect(reason)}")

    {:noreply, state}
  end

  @impl true
  def handle_info(_, state), do: {:noreply, state}
end

defmodule Spigot.Transports.TCP.ClientSupervisor do
  use DynamicSupervisor

  @spec start_link(nil | maybe_improper_list | map) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(name) do
    name = :"#{name}_client_sup"

    DynamicSupervisor.start_link(__MODULE__, [], name: name)
  end

  @spec start_client(any) :: :ignore | {:error, any} | {:ok, pid} | {:ok, pid, any}
  def start_client(client_options) do
    spec = {
      Spigot.Transports.TCP.Client,
      client_options
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @impl true
  def init(_options) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
