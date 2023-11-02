defmodule Spigot.Transports.TCP.Client do
  use GenServer
  require Logger

  defstruct [
    :socket,
    :server,
    :server_port,
    :timeout,
    :retries,
  ]

  def start_link(host, port, options) do
    genserver_options =
      Keyword.get(options, :genserver_options, [])

    timeout =
      Keyword.get(options, :timeout, 10_000)

    retries =
      Keyword.get(options, :retries, 3)

    options =
      options
      |> Keyword.delete(:genserver_options)
      |> Keyword.put(:host, host)
      |> Keyword.put(:port, port)
      |> Keyword.put(:timeout, timeout)
      |> Keyword.put(:retries, retries)

    GenServer.start_link(__MODULE__, options, genserver_options)
  end

  def init(state) do
    state =
      struct(__MODULE__, state)

    {:ok, :connect, {:continue, state}}
  end

  def handle_continue(:connect, state) do
    with {:ok, socket} <- connect(state.host, state.port) do
      Map.put(state, :socket, socket)

      {:ok, state}
    else
      {:error, :timeout} ->
        if state[:retries] == 0 do
          Process.exit(self(), :timeout)
          {:stop, :shutdown, state}
        else
          state =
            Map.replace!(state, :retries, state[:retries] - 1)
          {:noreply, :connect, {:continue, state}}
        end
      _ = error ->
        Logger.error("#{inspect(error)}")
        {:stop, :shutdown, state}
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

  def connect(host, port, timeout \\ 10_000, options \\ [:inet, :binary, active: true, packet: :line]), do:
    :gen_tcp.connect(host, port, options, timeout)
end
