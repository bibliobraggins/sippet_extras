defmodule Spigot.Transports.UDP do
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
    GenServer.start_link(__MODULE__, options, name: options[:sockname])
  end

  @impl true
  def init(options) do
    case listen(options) do
      {:ok, socket} ->
        options = Keyword.put(options, :socket, socket)
        Logger.debug("started transport: #{inspect(options[:sockname])}")
        {:ok, options}
      error ->
        raise "an error occurred starting the UDP socket: #{inspect error}"
    end
  end

  @impl true
  def handle_info({:udp, _socket, _from_host, _from_port, msg}, options) do
    msg
    |> Message.parse!()
    |> inspect()
    |> Logger.debug()

    {:noreply, options}
  end


  @spec listen(list()) ::
          {:error, atom} | {:ok, port}
  def listen(options), do: :gen_udp.open(options[:port], options[:transport_options])


  def send_message(message, recipient, socket, family) do
    with {:ok, to_ip} <- Transport.resolve_name(recipient.host, family),
         iodata <- Message.to_iodata(message),
         :ok <- :gen_udp.send(socket, {to_ip, recipient.port}, iodata) do
      :ok
    else
      error ->
        error
    end
  end

  @impl true
  def terminate(reason, options) do
    Logger.info("terminating #{inspect(options[:sockname])}, reason: #{inspect(reason)}")
    :gen_udp.close(options[:socket])
  end

end
