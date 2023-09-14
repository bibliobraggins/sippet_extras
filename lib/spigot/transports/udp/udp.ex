defmodule Spigot.Transports.UDP do
  use GenServer

  alias Sippet.Message

  require Logger

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
              {:ok, {_,_,_,_} = ip} ->
                {ip, :inet}
              {:ok, {_,_,_,_,_,_,_,_} = ip} ->
                {ip, :inet6}
            end
         end

      port = Keyword.get(options, :port, 5060)

      sockname = :"#{(:inet.ntoa(ip))}:#{port}/udp"

      GenServer.start_link(__MODULE__, [user_agent: user_agent, ip: ip, port: port, family: family, sockname: sockname], name: sockname)
  end

  @impl true
  def init(opts) do
    IO.inspect opts
    case :gen_udp.open(opts[:port], [:binary, {:active, true}, {:ip, opts[:ip]}, opts[:family]]) do
      {:ok, socket} ->
        Logger.debug(
          "#{inspect(self())} started transport " <>
            "#{(:inet.ntoa(opts[:ip]))}:#{opts[:port]}/udp"
        )

        {:ok, Keyword.put_new(opts, :socket, socket)}

      {:error, reason} ->
        Logger.error(
          "#{inspect(self())} port #{opts[:port]}/udp :: #{inspect(reason)}"
        )
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
end
