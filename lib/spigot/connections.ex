defmodule Spigot.Connections do
  def table(spigot), do: :"#{spigot}.connections"

  def init(spigot),
    do: :ets.new(table(spigot), [:named_table, :set, :public, {:write_concurrency, true}])

  def key(ip, port), do: :erlang.term_to_binary({ip, port})

  def connect(connections, {ip, port}, handler),
    do: :ets.insert(connections, {key(ip, port), handler})
  def connect(connections, ip, port, handler),
    do: :ets.insert(connections, {key(ip, port), handler})

  @spec disconnect(atom | :ets.tid(), map | binary) :: true
  def disconnect(connections, peer = %{address: _, port: _, ssl_cert: _}),
    do: disconnect(connections, key(peer.address, peer.port))

  def disconnect(connections, key) when is_binary(key),
    do: :ets.delete(connections, key)

  @spec lookup(atom | :ets.tid(), binary()) :: [tuple]
  def lookup(connections, key),
    do: :ets.lookup(connections, key) |> IO.inspect()

  def lookup(connections, host, port),
    do: :ets.lookup(connections, key(host, port))
end
