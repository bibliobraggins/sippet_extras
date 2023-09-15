defmodule Spigot.Transport do
  @callback listen(options :: keyword()) :: {:ok, Types.socket()} | {:error, term()}

  @callback connect(address :: Types.address(), port :: :inet.port_number()) ::
              {:ok, Types.socket()} | {:ok, Types.transport(), Types.address()} | {:error, term()}

  @callback negotiated_protocol(Types.socket()) :: {:ok, protocol :: binary()} | {:error, term()}

  @callback send_message(Types.message(), tuple()) :: :ok | {:error, term()}

  @callback close(Types.socket()) :: :ok | {:error, term()}

  @callback recv(Types.socket(), bytes :: non_neg_integer(), timeout()) ::
              {:ok, binary()} | {:error, term()}

  @callback controlling_process(Types.socket(), pid()) :: :ok | {:error, term()}

  @callback setopts(Types.socket(), opts :: keyword()) :: :ok | {:error, term()}

  @callback getopts(Types.socket(), opts :: keyword()) ::
              {:ok, opts :: keyword()} | {:error, term()}

  @optional_callbacks [
    connect: 2,
    setopts: 2,
    getopts: 2,
    controlling_process: 2,
    negotiated_protocol: 1,
    recv: 3
  ]

  def get_family(host) when is_list(host) do
    case :inet.parse_address(host) do
      {:ok, host} ->
        host |> get_family()

      error ->
        error
    end
  end

  def get_family(host) when is_tuple(host) do
    case host do
      {_, _, _, _} -> :inet
      {_, _, _, _, _, _, _} -> :inet6
    end
  end

  @spec resolve_name(binary, :inet | :inet6 | :local) ::
          {:error, :eafnosupport | :einval | :nxdomain}
          | {:ok,
             {byte, byte, byte, byte}
             | {char, char, char, char, char, char, char, char}}
  def resolve_name(host, family) do
    host
    |> String.to_charlist()
    |> :inet.getaddr(family)
  end
end
