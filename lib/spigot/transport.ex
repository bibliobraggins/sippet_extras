defmodule Spigot.Transport do

  @callback build_options(options :: keyword()) ::
              {module(), list()} | {:error, term()}

  @callback listen(options :: keyword()) ::
              {:ok, Types.socket()} | {:error, term()}

  @callback connect(binary(), :inet.port_number(), opts :: keyword()) ::
              {:ok, term()} | {:error, term()}

  @callback send_message(Types.message(), term(), keyword()) ::
              :ok | {:error, term()}

  @callback close(Types.socket()) ::
              :ok | {:error, term()}

  @optional_callbacks [
    connect: 3
  ]

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
