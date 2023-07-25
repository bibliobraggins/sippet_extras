defmodule Sippet.Transports.TCP do
  @moduledoc """
  Implements a TCP transport via ThousandIsland
  """

  use GenServer

  require Logger

  alias Sippet.Message, as: Message
  alias Sippet.Transports.Connections, as: Connections
  alias Sippet.Transports.TCP.Server, as: Server

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

    GenServer.start_link(__MODULE__,
      name: name,
      ip: ip,
      port: port,
      family: family,
      registry: :"#{name}_registry"
    )
  end

  @impl true
  def init(state) do
    {:ok, nil, {:continue, state}}
  end

  @impl true
  def handle_continue(state, nil) do
    children = [
      {Connections, state[:registry]},
      {ThousandIsland,
       port: state[:port],
       transport_options: [ip: state[:ip]],
       handler_module: Server,
       handler_options: [
         name: state[:name],
         family: state[:family],
         registry: state[:registry]
       ]}
    ]

    with {:ok, _pid} <- Supervisor.start_link(children, strategy: :one_for_one),
         :ok <- Sippet.register_transport(state[:name], :tcp, true) do
      {:noreply, state}
    else
      error ->
        raise "could not start tcp socket, reason: #{inspect(error)}"
    end
  end

  @impl true
  def handle_call({:send_message, %Message{} = message, to_host, to_port, key}, _from, state) do
    with {:ok, to_ip} <- resolve_name(to_host, state[:family]),
         {:ok, handler} when is_pid(handler) <- lookup_conn(state[:registry], to_ip, to_port) do

      send(handler, {:send_message, message})
    else
      error ->
        Logger.error("problem sending message #{inspect(key)}, reason: #{inspect(error)}")
    end

    {:reply, :ok, state}
  end

  defp lookup_conn(registry, to_host, to_port) do
    try do
      GenServer.call(registry, {:lookup, to_host, to_port}, 5000)
    rescue
      reason ->
        Logger.emergency(
          "could not lookup handler pid, registry process is not responsive, reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def resolve_name(host, family) do
    host
    |> String.to_charlist()
    |> :inet.getaddr(family)
  end
end
