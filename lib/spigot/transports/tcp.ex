defmodule Spigot.Transports.TCP do
  @moduledoc """
  Implements a TCP transport via ThousandIsland
  """

  require Logger
  use GenServer

  alias Spigot.{Transport, Transports.TCP.Client}
  alias Sippet.{Message, Message.RequestLine, Message.StatusLine}

  def child_spec(options) do
    ip = Keyword.get(options, :ip, {0, 0, 0, 0})

    transport_options = [
      :binary,
      ip: ip
    ]

    client_options =
      Keyword.get(options, :client_options, [])

    options =
      options
      |> Keyword.put(:reuseport, true)
      |> Keyword.put(:transport_options, transport_options)
      |> Keyword.put(:client_options, client_options)

    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [options]}
    }
  end

  def start_link(options) do
    options = Keyword.put(options, :connections, Transport.start_table(options[:spigot]))

    GenServer.start_link(__MODULE__, options, name: options[:spigot])
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
           handler_options: [
             user_agent: options[:user_agent],
             connections: options[:connections],
             spigot: options[:spigot]
           ]
         ) do
      {:ok, pid} ->
        Logger.info("started transport: #{inspect(options[:spigot])}")
        {:ok, Keyword.put_new(options, :socket, pid)}

      {:error, _} = err ->
        raise("could not start TCP transport: #{inspect(err)}")
    end
  end

  @impl true
  def handle_call(
        {:send_message, %Message{start_line: %RequestLine{}} = request, _key,
         {_protocol, host, port}},
        _from,
        state
      ) do
    with {:ok, to_ip} <- Transport.resolve_name(host, state[:family]) do
      case Transport.lookup(state[:connections], to_ip, port) do
        [{_key, handler}] ->
          send(handler, {:send_message, request})

        [] ->
          case Client.start_link(to_ip, port, state) do
            {:ok, client} when is_pid(client) ->
              :ok
            error ->
              Logger.warning("Client got error: #{inspect(error)}")
          end
      end
    else
      {:error, reason} ->
        Logger.warning("TCP error:  #{host}:#{port}: #{inspect(reason)}")
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(
        {:send_message, %Message{start_line: %StatusLine{}} = response, _key,
         {_protocol, host, port}},
        _from,
        state
      ) do
    with {:ok, to_ip} <- Transport.resolve_name(host, state[:family]) do
         case Transport.lookup(state[:connections], to_ip, port) do
          [{_key, handler}] ->
            send(handler, {:send_message, response})

            {:reply, :ok, state}
          [] ->
            {:reply, {:error, :no_handler}, state}
         end
    end
  end

  @impl true
  def terminate(reason, state) do
    Logger.warning("SHUTTING DOWN SOCKET HOLDING PROCESS: #{inspect(state[:spigot])}")

    Process.exit(self(), reason)
  end

  def send_message(message, pid, _options) do
    send({:send_message, message}, pid)
  end

  def close(pid, timeout \\ 15000), do: ThousandIsland.stop(pid, timeout)

end
