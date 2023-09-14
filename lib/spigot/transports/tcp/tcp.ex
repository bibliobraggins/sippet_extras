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
        _ ->
          raise ArgumentError, "a UserAgent module must be provided to use this transport"
      end

    transport_module =
      case options[:scheme] do
        :sips ->
          ThousandIsland.Transports.SSL
        _ ->
          ThousandIsland.Transports.TCP
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
        {:ok, ip} when is_tuple(ip) ->
          ip

        {:error, reason} ->
          raise ArgumentError,
                ":address contains an invalid IP or DNS name, got: #{inspect(reason)}"
      end

    transport_options =
      Keyword.get(options, :transport_options, [])
      |> Keyword.put_new(:ip, ip)
      |> Keyword.put_new(:reuseaddr, true)

    options =
      Keyword.put_new(options, :transport_module, transport_module)
      |> Keyword.put_new(:user_agent, user_agent)
      |> Keyword.put_new(:transport_options, transport_options)
      |> Keyword.put_new(:port, port)

    GenServer.start_link(__MODULE__, options)
  end

  @impl true
  def init(options) do
    case ThousandIsland.start_link(
      port: options[:port],
      handler_module: Spigot.Transports.TCP.Handler,
      transport_module: options[:transport_module],
      transport_options: options[:transport_options],
      handler_options: [user_agent: options[:user_agent]]
    ) do
      {:ok, pid} ->
        Logger.debug(
          "#{inspect(self())} started transport " <>
            "#{inspect(options[:transport_options][:ip])}:#{options[:port]}/tcp"
        )
        {:ok, pid}
      {:error, reason} ->
        Logger.error(
          "#{inspect(self())} port #{options[:port]}/tcp :: #{inspect(reason)}"
        )
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
