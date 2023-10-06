defmodule Spigot.Connections do

  def table(socket_name), do:
    :"#{socket_name}.connections"

  def init(socket_name), do: :ets.new(table(socket_name), [:named_table,:set,:public,{:write_concurrency, true}])

  @spec key(:inet.ip_address(), 0..65535) :: binary
  def key(ip, port), do: :erlang.term_to_binary({ip, port})

  @spec connect(atom | :ets.tid(), binary | map, pid | atom) :: boolean
  def connect(connections, peer = %{address: _, port: _, ssl_cert: _}, handler),
    do: connect(connections, key(peer.address, peer.port), handler)

  def connect(connections, key, handler) when is_binary(key),
    do: :ets.insert(connections, {key, handler})

  @spec disconnect(atom | :ets.tid(), map | binary) :: true
  def disconnect(connections, peer = %{address: _, port: _, ssl_cert: _}),
    do: disconnect(connections, key(peer.address, peer.port))

  def disconnect(connections, key) when is_binary(key),
    do: :ets.delete(connections, key)

  @spec lookup(atom | :ets.tid(), binary()) :: [tuple]
  def lookup(connections, key),
    do: :ets.lookup(connections, key)

  def lookup(connections, host, port),
    do: :ets.lookup(connections, key(host, port))

end
