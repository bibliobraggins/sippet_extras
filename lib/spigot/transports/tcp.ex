defmodule Spigot.Transports.TCP do
  @moduledoc """
  Implements a TCP transport via ThousandIsland
  """

  require Logger
  use GenServer

  alias Spigot.{Transport, Connections}
  # alias Sippet.Message, as: Message
  # alias Message.RequestLine, as: Request
  # alias Message.StatusLine, as: Response

  def child_spec(options) do
    {ip, options} = Keyword.pop(options, :ip)

    transport_options = [
      ip: ip,
      reuseport: true
    ]

    options =
      options
      |> Keyword.put(:reuseport, true)
      |> Keyword.put(:transport_options, transport_options)

    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [options]}
    }
  end

  def start_link(options) do
    options = Keyword.put(options, :connections, Connections.init(options[:socket_name]))

    GenServer.start_link(__MODULE__, options, name: options[:socket_name])
  end

  @doc """
  Starts the TCP transport.
  """
  @impl true
  def init(options) do
    transport_module =
      case Keyword.fetch(options, :transport) do
        {:ok, :tls} ->
          ThousandIsland.Transports.SSL

        _ ->
          ThousandIsland.Transports.TCP
      end

    case ThousandIsland.start_link(
           port: options[:port],
           handler_module: Spigot.Transports.TCP.Server,
           transport_module: transport_module,
           transport_options: options[:transport_options],
           handler_options: [user_agent: options[:user_agent]]
         ) do
      {:ok, pid} ->
        Logger.info("started transport: #{inspect(options[:socket_name])}")
        {:ok, Keyword.put_new(options, :socket, pid)}

      {:error, _} = err ->
        raise("could not start TCP transport: #{inspect(err)}")
    end
  end

  def connect(to_host, to_port, options) do
    family = Transport.get_family(to_host)

    with {:ok, to_ip} <- Transport.resolve_name(to_host, family) do
      :gen_tcp.connect(to_ip, to_port, options)
    else
      error ->
        error
    end
  end

  def send_message(message, pid, _options) do
    send({:send_message, message}, pid)
  end

  def close(pid, timeout \\ 15000), do: ThousandIsland.stop(pid, timeout)
end
