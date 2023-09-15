defmodule Spigot.Transports.UDP do
  @behaviour Spigot.Transport

  alias Sippet.Message
  alias Spigot.Transport

  require Logger

  @impl Transport
  def build_options(opts) do
    opts =
      opts
      |> Keyword.put_new(:socket_opts, [opts[:family], :binary, ip: opts[:ip], active: true])

    {__MODULE__, opts}
  end

  @impl true
  def listen(opts) do
    :gen_udp.open(opts[:port], opts[:socket_opts])
  end

  @impl Spigot.Transport
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
end
