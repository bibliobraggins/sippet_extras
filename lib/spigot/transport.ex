defmodule Spigot.Transport do
  def worker_spec(spigot) do
    [
      {
        Registry,
        name: :"#{spigot}.Registry", keys: :unique, partitions: System.schedulers_online()
      },
      {
        DynamicSupervisor,
        strategy: :one_for_one, name: :"#{spigot}.Supervisor"
      }
    ]
  end

  def table(spigot), do: :"#{spigot}.table"

  def start_table(spigot),
    do: :ets.new(table(spigot), [:named_table, :set, :public, {:write_concurrency, true}])

  def key(ip, port), do: :erlang.term_to_binary({ip, port})

  def handle_connection(table, ip, port, handler),
    do: :ets.insert(table, {key(ip, port), handler})

  def  handle_disconnection(table, address, port),
    do: handle_disconnection(table, key(address, port))

  def handle_disconnection(table, key) when is_binary(key),
    do: :ets.delete(table, key)

  @spec lookup(atom | :ets.tid(), binary()) :: [tuple]
  def lookup(table, key),
    do: :ets.lookup(table, key)

  def lookup(table, host, port),
    do: :ets.lookup(table, key(host, port))

  def get_family(host) when is_binary(host),
    do: host |> to_charlist() |> get_family()

  def get_family(host) when is_list(host) do
    case :inet.parse_address(host) do
      {:ok, host} ->
        get_family(host)

      {:error, error} ->
        raise("invalid ip address, got: #{inspect(error)}")
    end
  end

  def get_family({_, _, _, _}), do: :inet
  def get_family({_, _, _, _, _, _, _}), do: :inet6

  def get_ip(address, family) do
    case resolve_name(address, family) do
      {:ok, ip} when is_tuple(ip) ->
        ip

      {:error, reason} ->
        raise ArgumentError,
              ":address contains an invalid IP or DNS name, got: #{inspect(reason)}"
    end
  end

  def resolve_name(host, family) do
    host
    |> String.to_charlist()
    |> :inet.getaddr(family)
  end
end
