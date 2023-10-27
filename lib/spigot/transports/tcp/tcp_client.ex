defmodule Spigot.Transports.TCP.Client do
  use GenServer
  require Logger

  def start_link(options) do
    genserver_options =
      Keyword.get(options, :genserver_options, [])

    timeout =
      Keyword.get(options, :timeout, 10_000)

    retries =
      Keyword.get(options, :retries, 3)

    options =
      options
      |> Keyword.delete(:genserver_options)
      |> Keyword.put(:timeout, timeout)
      |> Keyword.put(:retries, retries)

    GenServer.start_link(__MODULE__, options, genserver_options)
  end

  def init(state) do
    state =
      Keyword.put(
        state,
        :tcp_options,
        [:inet, :binary, active: true, packet: :line]
      )

    {:ok, :connect, {:continue, state}}
  end

  def handle_continue(:connect, state) do
    with {:ok, socket} <- :gen_tcp.connect(state[:host], state[:port], state[:tcp_options]) do
      Keyword.put(state, :socket, socket)

      {:ok, state}
    else
      {:error, :timeout} ->
        if state[:retries] == 0 do
          Process.exit(self(), :timeout)
        end

        state =
          Keyword.replace!(state, :retries, state[:retries] - 1)

        {:noreply, :connect, {:continue, state}}
    end
  end

  def handle_info({:tcp, _socket, data}, state) do
    Logger.debug("""
    GOT RESPONSE:
    #{inspect(data)}
    """)

    {:noreply, state}
  end

  def handle_info({:send_message, io_msg}, state) do
    :gen_tcp.send(state[:socket], io_msg)
    {:noreply, state}
  end
end
