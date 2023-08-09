defmodule Spigot.Transports.TCP do
  @moduledoc """
  Implements a TCP transport via ThousandIsland
  """

  use GenServer

  require Logger

  alias Sippet.Message, as: Message
  alias Message.RequestLine, as: Request
  alias Message.StatusLine, as: Response
  alias Spigot.Transports.TCP.Server, as: Server

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

    connections = :ets.new(:"#{name}_connections", [
             :named_table,
             :set,
             :public,
             {:write_concurrency, true}
           ])

    GenServer.start_link(__MODULE__,
      name: name,
      ip: ip,
      port: port,
      family: family,
      connections: connections,
      clients: :"#{options[:name]}_client_sup"
    )
  end

  @impl true
  def init(options) do
    {:ok, nil, {:continue, options}}
  end

  @impl true
  def handle_continue(options, nil) do
    children = [
      {DynamicSupervisor, name: options[:clients]},
      {ThousandIsland,
       port: options[:port],
       transport_options: [ip: options[:ip]],
       handler_module: Server,
       handler_options: [
         name: options[:name],
         family: options[:family],
         connections: options[:connections]
       ]}
    ]

    with {:ok, _pid} <- Supervisor.start_link(children, strategy: :one_for_one),
         :ok <- Sippet.register_transport(options[:name], :tcp, true) do
      Logger.debug(
        "#{inspect(self())} started transport #{stringify_sockname(options[:ip], options[:port])}/tcp"
      )

      {:noreply, options}
    else
      error ->
        Logger.error("could not start tcp socket, reason: #{inspect(error)}")
        Process.sleep(5_000)
        {:noreply, nil, {:continue, options}}
    end
  end

  @impl true
  def handle_call(
        {:send_message, %Message{start_line: %Request{}} = _message, _to_host, _to_port, _key},
        _from,
        state
      ) do
    # if the message is a request and we have no pid available for a given peer,
    # we spawn a Client GenServer that spawns a socket in active mode for the
    # transaction.

    # lookup_conn(state[:connections], to_host, to_port)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(
        {:send_message, %Message{start_line: %Response{}} = message, to_host, to_port, key},
        _from,
        state
      ) do
    # if the message is a request and we have no pid available for a given peer,
    # we spawn a Client GenServer that spawns a socket in active mode for the
    # transaction.
    lookup_and_send(state[:connections], to_host, to_port, state[:family], message, key)

    {:reply, :ok, state}
  end

  @spec key(:inet.ip_address(), 0..65535) :: binary
  def key(host, port), do: :erlang.term_to_binary({host, port})

  @spec connect(atom | :ets.tid(), any, any, any) :: boolean
  def connect(connections, host, port, handler),
    do: :ets.insert_new(connections, {key(host, port), handler})

  @spec disconnect(atom | :ets.tid(), any, any) :: true
  def disconnect(connections, host, port),
    do: :ets.delete(connections, key(host, port))

  @spec lookup_conn(atom | :ets.tid(), any, any) :: [tuple]
  def lookup_conn(connections, host, port),
    do: :ets.lookup(connections, key(host, port))

  defp lookup_and_send(connections, to_host, to_port, family, message, key) do
    with {:ok, to_ip} <- resolve_name(to_host, family) do
      case lookup_conn(connections, to_ip, to_port) do
        [{_key, handler}] when is_pid(handler) ->
          send(handler, {:send_message, message})

        [] ->
          nil
          # DynamicSupervisor.start_child(state[:clients], )
      end
    else
      error ->
        Logger.error("problem sending message #{inspect(key)}, reason: #{inspect(error)}")
    end
  end

  def resolve_name(host, family) do
    host
    |> String.to_charlist()
    |> :inet.getaddr(family)
  end

  @spec resolve_name(binary, atom, :naptr | :srv | :a) :: :todo
  def resolve_name(_host, _family, _type), do: :todo

  def stringify_sockname(ip, port) do
    address =
      ip
      |> :inet_parse.ntoa()
      |> to_string()

    "#{address}:#{port}"
  end
end
