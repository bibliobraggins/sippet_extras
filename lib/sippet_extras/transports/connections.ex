defmodule Sippet.Transports.Connections do
  @spec init(atom()) :: :ets.tid()
  def init(name),
    do: :ets.new(name, [:set, :public, {:write_concurrency, true}])

  @spec key(:inet.ip_address(), :inet.port_number()) :: binary()
  def key(ip, port), do: :erlang.term_to_binary({ip, port})

  @spec handle_connection(
          :ets.tid(),
          :inet.ip_address(),
          :inet.port_number(),
          pid()
        ) :: true
  def handle_connection(table, ip, port, handler),
    do: :ets.insert(table, {key(ip, port), handler})

  @spec handle_disconnection(
          atom() | :ets.tid(),
          :inet.ip_address(),
          :inet.port_number()
        ) :: true
  def handle_disconnection(table, address, port),
    do: handle_disconnection(table, key(address, port))

  @spec handle_disconnection(atom() | :ets.tid(), binary()) :: true
  def handle_disconnection(table, key) when is_binary(key),
    do: :ets.delete(table, key)

  @spec lookup(atom | :ets.tid(), binary()) :: [tuple]
  def lookup(table, key),
    do: :ets.lookup(table, key)

  @spec lookup(
          atom() | :ets.tid(),
          :inet.ip_address(),
          :inet.port_number()
        ) :: [tuple()]
  def lookup(table, host, port),
    do: :ets.lookup(table, key(host, port))

  @spec teardown(:ets.tid()) :: true
  def teardown(table), do: :ets.delete(table)
end
