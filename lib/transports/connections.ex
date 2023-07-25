defmodule Sippet.Transports.Connections do
  use GenServer
  require Logger

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: name)
  end

  @impl true
  def init(name) do
    children =
      [
        {Registry, name: :connections, keys: :unique}
      ]

    case Supervisor.start_link(children, strategy: :one_for_one) do
      {:ok, pid} when is_pid(pid) -> {:ok, nil}
      error ->
        raise "failed to start #{inspect(name)}, reason: #{inspect(error)}"
    end
  end

  defp do_register(peer_info, handler), do: Registry.register(:connections, peer_info, handler)

  defp do_unregister({peer_info}), do: Registry.unregister(:connections, peer_info)

  defp do_lookup(host, port) do
    case Registry.lookup(:connections, {host, port}) do
      [{_pid, pid}] ->
        Logger.debug(inspect(pid))
        {:ok, pid}

      [] ->
        Logger.error("no client transactions supported yet")
        {:ok, nil}
    end
  end

  @impl true
  def handle_call({:lookup, {host, port}}, _from, state) do
    {:reply, do_lookup(host, port), state}
  end

  @impl true
  def handle_call({:register, host, port}, {handler, _}, state) do
    Logger.debug(inspect(do_register({host, port}, handler)))
    {:reply, do_register({host, port}, handler), state}
  end

  @impl true
  def handle_call({:unregister, peer_info}, _from, state) do
    {:reply, do_unregister(peer_info), state}
  end
end
