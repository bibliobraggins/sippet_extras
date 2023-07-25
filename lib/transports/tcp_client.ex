defmodule Sippet.Transports.TCP.Client do
  use GenServer

  alias Sippet.Message, as: Msg
  import Sippet.Transports.TCP

  def start_link(options) do
    # [transport: pid(), timeout: non_neg_integer(), registry: atom()]

    registry =
      case Keyword.fetch(options, :registry) do
        {:ok, pid} when is_pid(pid) ->
          pid
        _ ->
          raise "no registry pid provided to #{inspect(__MODULE__)}, #{inspect(self())}"
      end

   peer =
      case Keyword.fetch(options, :peer) do
        {:ok, {addr, port}} ->
          {addr, port}
        _ ->
          raise "no{peer_addr, peer_port} data provided to #{inspect(__MODULE__)}, #{inspect(self())}"
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
    init_msg =
      with {:ok, init_msg = %Msg{}} <- Keyword.fetch(options, :init_msg),
          true <- Msg.valid?(init_msg)
      do
        init_msg
      else
        _ ->
          raise "initial message must be a valid SIP message"
      end

    state = [ip: ip, registry: registry, family: family, peer: peer, timeout: timeout, init_msg: init_msg, retries: 5]

    GenServer.start_link(__MODULE__, state)
  end

  @impl true
  def init(state) do
    {:ok, :connect, {:continue, state}}
  end

  @impl true
  def handle_continue(state, :connect) do
    {addr, port} = state[:peer]

    case :gen_tcp.connect(addr, port, [:binary, {:active, true}, {:ip, state[:ip]}, state[:family]], state[:timeout]) do
      {:ok, socket} ->
        {:noreply, Keyword.put(state, :socket, socket)}
      {:error, reason} ->
        raise "could not connect to #{inspect(addr)}:#{inspect(port)} :: #{inspect(reason)}"
        {:noreply, :connect, {:continue, Keyword.put(state, :retries, (state[:retries] - 1))}}
    end
  end

end
