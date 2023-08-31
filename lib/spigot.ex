defmodule Spigot do
  use Supervisor

  alias Spigot.Types

  alias Sippet.URI, as: SIPURI

  @moduledoc """
    options = [
      :name,
      :transport,
      :address,
      :port,
      :family,
      :user_agent
  """

  @type transport :: :udp | :tcp | :tls | :ws | :wss

  @type transport_options :: [
          address: Types.address(),
          port: :inet.port_number(),
          proxy: binary() | SIPURI.t()
        ]

  @type ws_options :: [
          enabled: boolean(),
          plug: Plug.t()
        ]

  @type options :: [
          user_agent: module() | {module(), keyword()},
          transport: transport(),
          transport_options: transport_options(),
          scheme: :sip | :sips,
          keyfile: binary(),
          certfile: binary(),
          otp_app: binary() | atom(),
          cipher_suite: :string | :compatible
        ]

  @spec start_link(nil | maybe_improper_list | map) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(options) do
    user_agent =
      case Code.ensure_loaded(options[:user_agent]) do
        {:module, module} when is_atom(module) ->
          module

        reason ->
          raise ArgumentError,
                "a valid module was not provided as a UserAgent, error: #{inspect(reason)}"
      end

    transport_module =
      case options[:transport] do
        :udp -> Sippet.Transports.UDP
        :tcp -> Spigot.Transports.TCP
        :tls -> Spigot.Transports.TCP
        :ws -> Spigot.Transports.WS
        :wss -> Spigot.Transports.WS
        _ -> Sippet.Transports.UDP
      end

    Supervisor.start_link(__MODULE__, {user_agent, transport_module, options})
  end

  @impl true
  def init({user_agent, transport_module, options}) do
    children = [
      {transport_module, Keyword.merge([user_agent: user_agent], options)},
      {user_agent, options}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
