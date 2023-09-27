defmodule Spigot.Transports.UDP do
  @behaviour Spigot.Transport

  alias Sippet.Message
  alias Spigot.Transport
  import Spigot.Transport

  require Logger

  @impl true
  def build_options(opts) do
    port = Keyword.get(opts, :port, 5060)
    mtu = Keyword.get(opts, :mtu, 1500)
    timeout = Keyword.get(opts, :io_timeout, 50000)

    opts =
      opts
      |> Keyword.put(:port, port)
      |> Keyword.put(:mtu, mtu)
      |> Keyword.put(:io_timeout, timeout)
      |> Keyword.put(:transport_options, [
        get_family(opts[:ip]),
        :binary,
        ip: opts[:ip],
        active: false
      ])

    {__MODULE__, opts}
  end

  @impl true
  def init(opts) do
    case :gen_udp.open(opts[:port], opts[:transport_options]) do
      {:ok, socket} ->
        spawn(fn -> recv_loop(opts[:sockname], socket, opts[:mtu], opts[:io_timeout]) end)
        {:ok, socket}
    end
  end

  @impl true
  def send_message(message, recipient, socket) do
    family = Transport.get_family(recipient.host)

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
  def close(socket),
    do: :gen_udp.close(socket)

  defp recv(socket, mtu, timeout) do
    case :gen_udp.recv(socket, mtu, timeout) do
      {:ok, msg} ->
        {:ok, msg}

      {:error, _} = error ->
        error
    end
  end

  defp recv_loop(sockname, socket, mtu, timeout) do
    case recv(socket, mtu, timeout) do
      {:ok, msg} ->
        Logger.debug("got io message: #{inspect(msg)}")

      {:error, :closed} ->
        Process.exit(self(), :shutdown)

      {:error, :timeout} ->
        Logger.warning("message timed out")

      {:error, error} ->
        Logger.warning("error handling message: #{inspect(error)}")
    end

    recv_loop(sockname, socket, mtu, timeout)
  end
end
