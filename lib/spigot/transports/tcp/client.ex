defmodule Spigot.Transports.TCP.Client do
  use GenServer
  require Logger

  alias Sippet.Message, as: Msg

  @type option :: :connections | :timeout | :peer | :socket | :start_message | :retries
  @type options :: [option]

  @enforce_keys [
    :connections,
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
    connections =
      case Keyword.fetch(options, :connections) do
        {:ok, connections} when is_atom(connections) ->
          connections

        _ ->
          raise "no connections pid provided to #{inspect(__MODULE__)}, #{inspect(self())}"
      end

    peer =
      case Keyword.fetch(options, :peer) do
        {:ok, %{address: _, port: _, ssl_cert: _} = peer} ->
          peer

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
      connections: connections,
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
  def handle_info(othr, state) do
    Logger.info("unexpected message: #{inspect(othr)}")
    {:noreply, state}
  end

  def resolve_name(host, family) do
    host
    |> String.to_charlist()
    |> :inet.getaddr(family)
  end

  def stringify_sockname(ip, port) do
    address =
      ip
      |> :inet_parse.ntoa()
      |> to_string()

    "#{address}:#{port}"
  end

end
