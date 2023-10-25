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
