defmodule Spigot.Transport.TCP.Client do
  require Logger

  use Supervisor

  @type t :: %{
          user_agent: module(),
          connections: :ets.table(),
          spigot: atom() | pid(),
          port: :inet.port_number(),
          transport_options: :inet.options(),
          genserver_options: GenServer.options(),
          retries: non_neg_integer(),
          retry_wait: non_neg_integer(),
          send_timeout: non_neg_integer(),
          shutdown_timeout: non_neg_integer(),
          silent_terminate_on_error: boolean()
        }

  @enforce_keys [
    :user_agent,
    :spigot,
    :port,
    :connections,
    :transport_options,
    :genserver_options
  ]

  defstruct @enforce_keys ++ []

  def child_spec(arg) do
    {__MODULE__, arg}
  end

  def start_link(%__MODULE__{} = config) do
    Supervisor.start_link(__MODULE__, config)
  end

  def init(_) do
    children = []

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
