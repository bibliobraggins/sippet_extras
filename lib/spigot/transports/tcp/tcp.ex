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

  @thousand_island_keys ThousandIsland.ServerConfig.__struct__()
                        |> Map.from_struct()
                        |> Map.keys()

  @doc """
  Starts the TCP transport.
  """
  def start_link(options) when is_list(options) do
    thousand_island_options =
      Keyword.get(options, :thousand_island_options, [])
      |> validate_options(@thousand_island_keys, :thousand_island_options)

    user_agent =
      case Keyword.fetch(options, :user_agent) do
        {:ok, user_agent} when is_atom(user_agent) ->
          user_agent

        {:ok, nil} ->
          raise ArgumentError, "a sippet must be provided to use this transport"

        :error ->
          raise ArgumentError, "a sippet must be provided to use this transport"
      end

    GenServer.start_link(__MODULE__,
      user_agent: user_agent,
      transport_options: options[:transport_options],
      thousand_island_options: thousand_island_options
    )
  end

  @impl true
  def init(options) do
    children = [
      {
        ThousandIsland,
        port: options[:port],
        handler_module: Spigot.Transports.TCP.ConnectionHandler,
        transport_module: options[:transport_module],
        transport_options: options[:transport_options] ++ [reuseaddr: true],
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

  defp validate_options(options, valid_values, name) do
    case Keyword.split(options, valid_values) do
      {options, []} ->
        options

      {_, illegal_options} ->
        raise "Unsupported keys(s) in #{name} config: #{inspect(Keyword.keys(illegal_options))}"
    end
  end
end
