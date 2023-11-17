defmodule Spigot.Transport do
  def workers(spigot) do
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

  @spec get_family(
          binary()
          | charlist()
          | :inet.ip_address()
        ) :: :inet | :inet6
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

  @spec get_ip(binary(), :inet | :inet6 | :local) ::
          :inet.ip_address()
  def get_ip(address, family) do
    case resolve_name(address, family) do
      {:ok, ip} when is_tuple(ip) ->
        ip

      {:error, reason} ->
        raise ArgumentError,
              ":address contains an invalid IP or DNS name, got: #{inspect(reason)}"
    end
  end

  @spec resolve_name(binary(), :inet | :inet6 | :local) ::
          {:error, :eafnosupport | :einval | :nxdomain}
          | {:ok, :inet.ip_address()}
  def resolve_name(host, family) do
    host
    |> String.to_charlist()
    |> :inet.getaddr(family)
  end
end
