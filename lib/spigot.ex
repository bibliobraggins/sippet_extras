defmodule Spigot do
  alias Spigot.{Types, Transport}
  alias Sippet.{URI}

  @moduledoc """
    Spigot is the main interface for bringing up and querying the system

    Spigot starts it's own Dynamic supervisor (this module), then provides
    a way to start transports that are associated with your UserAgent module

    Spigot also takes most of it's concepts directly from the underlying
    Sippet library, but has been modified to allow associating many socket_name
    transports with the same UserAgent module.
  """

  @type transport :: :udp | :tcp | :tls | :ws | :wss

  @type transport_options :: [
          address: Types.address(),
          port: :inet.port_number(),
          proxy: binary() | URI.t()
        ]

  @type websocket_name_options :: [
          enabled: boolean(),
          max_frame_size: pos_integer(),
          validate_text_frames: boolean(),
          compress: boolean()
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

  def start_link(options) do
    user_agent = Keyword.get(options, :user_agent)
    address = Keyword.get(options, :address, "0.0.0.0")
    family = Transport.get_family(address)
    ip = Transport.get_ip(address, family)
    transport = Keyword.get(options, :transport, :udp)

    port =
      if Enum.member?([:ws, :wss], transport) do
        Keyword.get(options, :port, 4000)
      else
        Keyword.get(options, :port, 5060)
      end

    socket_name = :"#{address}:#{port}/#{transport}"

    options =
      []
      |> Keyword.put(:ip, ip)
      |> Keyword.put(:family, family)
      |> Keyword.put(:port, port)
      |> Keyword.put(:transport, transport)
      |> Keyword.put(:socket_name, socket_name)
      |> Keyword.put(:user_agent, user_agent)

    Supervisor.start_link(__MODULE__, options)
  end

  def init(options) do
    children = [
      setup_transport(options),
      {
        Registry,
        name: :"#{options[:socket_name]}.Registry",
        keys: :unique,
        partitions: System.schedulers_online()
      },
      {
        DynamicSupervisor,
        strategy: :one_for_one, name: :"#{options[:socket_name]}.Supervisor"
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp setup_transport(options) do
    mod =
      case options[:transport] do
        :udp ->
          Spigot.Transports.UDP

        :tcp ->
          Spigot.Transports.TCP

        :tls ->
          Spigot.Transports.TCP

        :ws ->
          Spigot.Transports.WS

        :wss ->
          Spigot.Transports.WS

        _ ->
          raise "must provide a supported transport option"
      end

    mod.child_spec(options)
  end

end
