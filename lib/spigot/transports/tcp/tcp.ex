defmodule Spigot.Transports.TCP do
  @moduledoc """
  Implements a TCP transport via ThousandIsland
  """

  use GenServer

  require Logger

  # alias Sippet.Message, as: Message
  # alias Message.RequestLine, as: Request
  # alias Message.StatusLine, as: Response
  alias Spigot.Transports.TCPServer, as: Server

  alias Spigot.Connections

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
    user_agent =
      case Keyword.fetch(options, :user_agent) do
        {:ok, user_agent} when is_atom(user_agent) ->
          user_agent

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
      case Connections.resolve_name(address, family) do
        {:ok, ip} ->
          ip

        {:error, reason} ->
          raise ArgumentError,
                ":address contains an invalid IP or DNS name, got: #{inspect(reason)}"
      end

    GenServer.start_link(__MODULE__,
      user_agent: user_agent,
      ip: ip,
      port: port,
      family: family,
      connections: Connections.init(Module.concat([user_agent, :connections]))
    )
  end

  @impl true
  def init(options) do
    {:ok, nil, {:continue, options}}
  end

  @impl true
  def handle_continue(options, nil) do
    children = [
      {ThousandIsland,
       port: options[:port],
       transport_options: [ip: options[:ip]],
       handler_module: Server,
       handler_options: [
         user_agent: options[:user_agent],
         family: options[:family],
         connections: options[:connections]
       ]}
    ]

    with {:ok, _pid} <- Supervisor.start_link(children, strategy: :one_for_one)
         #:ok <- Sippet.register_transport(options[:user_agent], :tcp, true)
        do
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

  def stringify_sockname(ip, port) do
    address =
      ip
      |> :inet_parse.ntoa()
      |> to_string()

    "#{address}:#{port}"
  end
end
