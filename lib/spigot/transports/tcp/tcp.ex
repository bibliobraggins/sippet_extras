defmodule Spigot.Transports.TCP do
  @moduledoc """
  Implements a TCP transport via ThousandIsland
  """

  require Logger

  use GenServer

  # alias Sippet.Message, as: Message
  # alias Message.RequestLine, as: Request
  # alias Message.StatusLine, as: Response

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

    port = Keyword.get(options, :port, 5060)

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
      user_agent: user_agent,
      ip: ip,
      port: port,
      family: family
    )
  end

  @impl true
  def init(options) do
    children = [
      {
        ThousandIsland,
        port: options[:port],
        transport_options: [ip: options[:ip]],
        handler_module: Spigot.Transports.TCP.ConnectionHandler,
        handler_options: [
          user_agent: options[:user_agent]
        ]
      }
    ]

    with {:ok, _pid} <- Supervisor.start_link(children, strategy: :one_for_one) do
      Logger.debug(
        "#{inspect(self())} started transport #{stringify_sockname(options[:ip], options[:port])}/tcp"
      )

      {:ok, options}
    else
      error ->
        {:error, error}
    end
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
