defmodule Spigot.Core.Transport do
  @type error :: {:error, term()}

  alias Spigot.Types

  @callback connect(address :: Types.address(), port :: :inet.port_number()) ::
              {:ok, Types.socket()} | {:ok, :udp, Types.address()} | error()

  @callback negotiated_protocol(Types.socket()) :: {:ok, protocol :: binary()} | error()

  @callback send(Types.socket(), Types.message()) :: :ok | error()

  @callback close(Types.socket()) :: :ok | error()

  @callback recv(Types.socket(), bytes :: non_neg_integer(), timeout()) ::
              {:ok, binary()} | error()

  @callback controlling_process(Types.socket(), pid()) :: :ok | error()

  @callback setopts(Types.socket(), opts :: keyword()) :: :ok | error()

  @callback getopts(Types.socket(), opts :: keyword()) :: {:ok, opts :: keyword()} | error()

  @callback wrap_err(reason :: term()) :: {:error, term()}
end
