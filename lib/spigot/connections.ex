defmodule Spigot.Connections do
  def table(spigot), do: :"#{spigot}.connections"

  def init(spigot),
    do: :ets.new(table(spigot), [:named_table, :set, :public, {:write_concurrency, true}])

  def key(ip, port), do: :erlang.term_to_binary({ip, port})

  def connect(connections, {ip, port}, handler),
    do: :ets.insert(connections, {key(ip, port), handler})

  def connect(connections, ip, port, handler),
    do: :ets.insert(connections, {key(ip, port), handler})

  def disconnect(connections, {address, port}),
    do: disconnect(connections, key(address, port))

  def disconnect(connections, key) when is_binary(key),
    do: :ets.delete(connections, key)

  @spec lookup(atom | :ets.tid(), binary()) :: [tuple]
  def lookup(connections, key),
    do: :ets.lookup(connections, key)

  def lookup(connections, host, port),
    do: :ets.lookup(connections, key(host, port))
end
