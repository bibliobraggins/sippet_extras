defmodule Sippet.Transports.TCP do
  @moduledoc """
  Implements a TCP transport via ThousandIsland
  """

  use GenServer

  require Logger

  alias Sippet.Message, as: Message

  @doc false
  def child_spec(options) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [options]}
    }
  end

  @doc """
  Starts the TCP transport.
  """
  def start_link(options) when is_list(options) do
    name =
      case Keyword.fetch(options, :name) do
        {:ok, name} when is_atom(name) ->
          name

        {:ok, nil} ->
          raise ArgumentError, "a sippet must be provided to use this transport"

        :error ->
          raise ArgumentError, "a sippet must be provided to use this transport"
      end

    port =
      case Keyword.fetch(options, :port) do
        {:ok, port} when is_integer(port) and port > 0 and port < 65536 ->
          port

        {:ok, nil} ->
          raise ArgumentError, "a port number must be provided to use this transport"

        :error ->
          raise ArgumentError, "could not use provided port, got: #{options[:port]}"
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

    ip =
      case resolve_name(address, family) do
        {:ok, ip} ->
          ip

        {:error, reason} ->
          raise ArgumentError,
                ":address contains an invalid IP or DNS name, got: #{inspect(reason)}"
      end

    GenServer.start_link(__MODULE__, name: name, ip: ip, port: port, family: family)
  end

  @impl true
  def init(state) do
    {:ok, nil, {:continue, state}}
  end

  @impl true
  def handle_continue(state, nil) do
    with {:ok, _pid} <- Registry.start_link(keys: :unique, name: :connections),
         {:ok, _pid} <-
           ThousandIsland.start_link(
             port: state[:port],
             handler_module: Sippet.Transports.TcpHandler,
             handler_options: [owner: self()],
             transport_options: [ip: state[:ip]]
           ),
         :ok <- Sippet.register_transport(state[:name], :tcp, true) do
      {:noreply, state}
    else
      _ ->
        Logger.warning("couldn't start transport process")
        {:noreply, nil, {:continue, state}}
    end
  end

  @impl true
  def handle_call({:send_message, message, _to_host, _to_port, _key}, _from, state) do
    Logger.debug("ready to resolve to sender process: #{to_string(message)}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:lookup, peer_info}, _from, state) do
    handler = do_lookup(peer_info)
    {:reply, handler, state}
  end

  @impl true
  def handle_cast({:register, peer_info, handler}, state) do
    do_register(peer_info, handler)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:unregister, peer_info}, state) do
    do_unregister(peer_info)
    {:noreply, state}
  end

  defp do_register(peer_info, handler) do
    "Registering #{inspect(peer_info)} to #{inspect(handler)}" |> Logger.debug()
    Registry.register(:connections, peer_info, handler)
  end

  defp do_unregister(peer_info), do: Registry.unregister(:connections, peer_info)

  defp do_lookup(peer_info) do
    case Registry.lookup(:connections, peer_info) do
      [{_, pid}] ->
        pid

      [] ->
        Logger.error("no connection handler was registered for this peer")
    end
  end

  defp resolve_name(host, family) do
    host
    |> String.to_charlist()
    |> :inet.getaddr(family)
  end
end
