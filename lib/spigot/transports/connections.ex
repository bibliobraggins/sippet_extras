defmodule Spigot.Connections do
  def init(name) when is_atom(name),
    do: :ets.new(name, [:bag, :named_table, :public, {:write_concurrency, true}])

  @spec lookup(atom | :ets.tid(), reference) :: [tuple]
  def lookup(table, key) when is_reference(key),
    do: :ets.lookup(table, key)

  @spec connect(atom | :ets.tid(), reference(), pid() | atom()) :: boolean
  def connect(table, key, handler),
    do: :ets.insert(table, {key, handler})

  @spec disconnect(atom | :ets.tid(), reference()) :: true
  def disconnect(table, key),
    do: disconnect(table, key)

  @spec delete(atom | :ets.tid()) :: true
  def delete(table),
    do: :ets.delete(table)

  @spec resolve_name(binary, :inet | :inet6 | :local) ::
          {:error, :eafnosupport | :einval | :nxdomain} | {:ok, :inet.ip_address()}
  def resolve_name(host, family) do
    host
    |> String.to_charlist()
    |> :inet.getaddr(family)
  end

  @spec resolve_name(binary, atom, :naptr | :srv | :a) :: :todo
  def resolve_name(_host, _family, _type),
    do: :todo
end
