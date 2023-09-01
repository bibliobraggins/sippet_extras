defmodule Spigot.Client do

  @type error :: {:error, term()}

  @callback init(Types.address(), Types.port(), opts :: keyword()) ::
    {:ok, Types.socket()} | error()

  @callback connect(Types.socket, Types.address(), Types.port(), opts :: keyword()) ::
    {:ok, Types.socket}

  @callback negotiated_protocol(Types.socket()) ::
    {:ok, protocol :: binary()} | error()

  @callback send(Types.socket(), term()) ::
    :ok | error()

  @callback recv(Types.socket(), bytes :: non_neg_integer(), timeout()) ::
    {:ok, binary()} | error()

  @callback close(Types.socket()) ::
    :ok | error()

  @callback controlling_process(Types.socket(), pid()) ::
    :ok | error()

  @callback setopts(Types.socket(), opts :: keyword()) ::
    :ok | error()

  @callback getopts(Types.socket(), opts :: keyword()) ::
    {:ok, opts :: keyword()} | error()

  @optional_callbacks [
    connect: 4,
    negotiated_protocol: 1,
    controlling_process: 2,
    setopts: 2,
    getopts: 2
  ]

end
