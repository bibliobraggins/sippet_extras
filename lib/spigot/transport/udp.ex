defmodule Spigot.Transport.UDP do
  use GenServer

  alias Spigot.Transport
  alias Sippet.Message

  require Logger

  def child_spec(options) do
    port = Keyword.get(options, :port, 5060)
    mtu = Keyword.get(options, :mtu, 1500)
    timeout = Keyword.get(options, :timeout, 10_000)

    options =
      options
      |> Keyword.put(:port, port)
      |> Keyword.put(:mtu, mtu)
      |> Keyword.put(:timeout, timeout)
      |> Keyword.put(:transport_options, [
        Transport.get_family(options[:ip]),
        :binary,
        ip: options[:ip],
        active: true
      ])

    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [options]}
    }
  end

  def start_link(options) do
    Transport.workers(options[:spigot])
    |> Supervisor.start_link(strategy: :one_for_all)

    GenServer.start_link(__MODULE__, options, name: options[:spigot])
  end

  @impl true
  def init(options) do
    case listen(options) do
      {:ok, socket} ->
        options = Keyword.put(options, :socket, socket)
        Logger.info("started transport: #{inspect(options[:spigot])}")
        {:ok, options}

      error ->
        raise "an error occurred starting the UDP socket: #{inspect(error)}"
    end
  end

  @impl true
  def handle_call({:send_message, message, key, {:udp, host, port}}, _from, state) do
    with {:ok, to_ip} <- Transport.resolve_name(host, state[:family]),
         iodata <- Message.to_iodata(message),
         :ok <- :gen_udp.send(state[:socket], {to_ip, port}, iodata) do
      :ok
    else
      {:error, reason} ->
        Logger.warning("udp transport error for #{host}:#{port}: #{inspect(reason)}")

        if key != nil do
          Spigot.Router.receive_transport_error(state[:spigot], key, reason)
        end
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:udp, _socket, host, port, msg}, state) do
    Spigot.Router.handle_transport_message(
      msg,
      {:udp, host, port},
      state[:user_agent],
      state[:spigot]
    )

    {:noreply, state}
  end

  def listen(state), do: :gen_udp.open(state[:port], state[:transport_options])

  @impl true
  def terminate(reason, options) do
    Logger.info("terminating #{inspect(options[:socket])}, reason: #{inspect(reason)}")
    :gen_udp.close(options[:socket])
  end
end
