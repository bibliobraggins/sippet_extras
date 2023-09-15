defmodule Spigot.Transports.UDP do
  @behaviour Spigot.Transport
  use GenServer

  alias Sippet.Message
  alias Spigot.Transport

  require Logger

  @spec start_link(keyword) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(options) when is_list(options) do
    user_agent =
      case Keyword.fetch(options, :user_agent) do
        {:ok, user_agent} when is_atom(user_agent) ->
          user_agent

        _ ->
          raise ArgumentError, "a UserAgent module must be provided to use this transport"
      end

    {ip, family} =
      Keyword.get(options, :address, "0.0.0.0")
      |> case do
        addr when is_binary(addr) ->
          to_charlist(addr)
          |> :inet.parse_address()
          |> case do
            {:ok, {_, _, _, _} = ip} ->
              {ip, :inet}

            {:ok, {_, _, _, _, _, _, _, _} = ip} ->
              {ip, :inet6}
          end
      end

    address = "#{:inet.ntoa(ip)}"

    port = Keyword.get(options, :port, 5060)

    sockname = :"#{address}:#{port}/udp"

    GenServer.start_link(
      __MODULE__,
      user_agent: user_agent,
      ip: ip,
      address: address,
      port: port,
      family: family,
      sockname: sockname
    )
  end

  @impl true
  def init(state) do
    case listen(state) do
      {:ok, socket} ->
        Logger.debug(
          "#{inspect(self())} started transport " <>
            "#{state[:address]}:#{state[:port]}/udp" <>
            "\t#{inspect(socket)}"
        )

        {:ok, Keyword.put_new(state, :socket, socket)}

      {:error, reason} ->
        Logger.error("#{inspect(self())} port #{state[:port]}/udp :: #{inspect(reason)}")
    end
  end

  @impl true
  def handle_info({:udp, _socket, _from_ip, _from_port, packet}, state) do
    case Message.parse!(packet) do
      result ->
        Logger.debug(inspect(result))
    end

    {:noreply, state}
  end

  @impl true
  def handle_call(
        {:send_message, message, to_host, to_port},
        _from,
        state
      ) do
    Logger.debug([
      "sending message to #{state[:sockname]}"
    ])

    case send_message(message, {to_host, to_port, state[:socket], state[:family]}) do
      :ok ->
        :ok

      error ->
        Logger.warning("udp transport error for #{state[:sockname]} :: #{inspect(error)}")
    end

    {:reply, :ok, state}
  end

  @impl true
  def send_message(message, {to_host, to_port, socket, family}) do
    with {:ok, to_ip} <- Transport.resolve_name(to_host, family),
         iodata <- Message.to_iodata(message),
         :ok <- :gen_udp.send(socket, {to_ip, to_port}, iodata) do
      :ok
    else
      error ->
        error
    end
  end

  @impl true
  def terminate(reason, state) do
    close(state[:socket])

    Logger.debug("stopped transport #{state[:sockname]}, reason: #{inspect(reason)}")
  end

  @impl true
  def listen(options) do
    port = Keyword.get(options, :port, 5060)
    ip = Keyword.get(options, :ip, {0, 0, 0, 0})
    family = Transport.get_family(ip)
    socket_options = [family, :binary, ip: ip, active: true]

    :gen_udp.open(port, socket_options)
  end

  @impl true
  def close(socket),
    do: :gen_udp.close(socket)
end
