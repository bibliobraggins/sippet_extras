defmodule Spigot.Transports.UDP do
  use GenServer

  alias Sippet.Message

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
      [
        user_agent: user_agent,
        ip: ip,
        address: address,
        port: port,
        family: family,
        sockname: sockname
      ],
      name: sockname
    )
  end

  @impl true
  def init(opts) do
    IO.inspect(opts)

    case :gen_udp.open(opts[:port], [:binary, {:active, true}, {:ip, opts[:ip]}, opts[:family]]) do
      {:ok, socket} ->
        Logger.debug(
          "#{inspect(self())} started transport " <>
            "#{opts[:address]}:#{opts[:port]}/udp"
        )

        {:ok, Keyword.put_new(opts, :socket, socket)}

      {:error, reason} ->
        Logger.error("#{inspect(self())} port #{opts[:port]}/udp :: #{inspect(reason)}")
    end
  end

  @impl true
  def handle_info({:udp, _socket, _from_ip, _from_port, packet}, opts) do
    case Message.parse!(packet) do
      result ->
        Logger.debug(inspect(result))
    end

    {:noreply, opts}
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

    with {:ok, to_ip} <- resolve_name(to_host, state[:family]),
         iodata <- Message.to_iodata(message),
         :ok <- :gen_udp.send(state[:socket], {to_ip, to_port}, iodata) do
      :ok
    else
      {:error, reason} ->
        Logger.warning("udp transport error for #{state[:sockname]}: #{inspect(reason)}")
    end

    {:reply, :ok, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.debug("stopped transport #{state[:sockname]}, reason: #{inspect(reason)}")

    :gen_udp.close(state[:socket])
  end

  defp resolve_name(host, family) do
    host
    |> String.to_charlist()
    |> :inet.getaddr(family)
  end
end
