defmodule Spigot do
  use Application

  alias Spigot.{Types, Transport}
  alias Sippet.URI, as: SIPURI

  @moduledoc """
    options = [
      :name,
      :transport,
      :address,
      :port,
      :family,
      :user_agent

    @main_keys ~w(transport port ip keyfile certfile otp_app cipher_suite websocket_plug thousand_island_options sip_options)a
    @sip_keys ~w(max_request_line_length max_header_length max_header_count max_requests compress deflate_options)a
    @websocket_keys ~w(enabled max_frame_size validate_text_frames compress)a
    @thousand_island_keys ThousandIsland.ServerConfig.__struct__()
                          |> Map.from_struct()
                          |> Map.keys()
  """

  @type transport :: :udp | :tcp | :tls | :ws | :wss

  @type transport_options :: [
          address: Types.address(),
          port: :inet.port_number(),
          proxy: binary() | SIPURI.t()
        ]

  @type websocket_options :: [
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

  def start(_, args) do
    args =
      Keyword.put_new(args, :strategy, :one_for_one)

    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    DynamicSupervisor.init(args)
  end

  def start_transport(options) do
    address = Keyword.get(options, :address, "0.0.0.0")
    family = Transport.get_family(address)
    ip = Transport.get_ip(address, family)
    port = Keyword.get(options, :port, 5060)
    transport = Keyword.get(options, :transport, :udp)

    options =
      options
      |> Keyword.put_new(:ip, ip)
      |> Keyword.put_new(:family, family)
      |> Keyword.put_new(:port, port)
      |> Keyword.put(:sockname, :"#{address}:#{port}/#{transport}")

    spec =
      case transport do
        :udp ->
          Spigot.Transports.UDP.child_spec(options)

        :tcp ->
          Spigot.Transports.TCP.child_spec(options)

        :tls ->
          Spigot.Transports.TCP.child_spec(options)

        :ws ->
          Spigot.Transports.WS.child_spec(options)

        :wss ->
          Spigot.Transports.WS.child_spec(options)

        _ ->
          raise "must provide a supported transport option"
      end

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

end
