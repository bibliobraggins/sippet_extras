defmodule Spigot do
  use Application

  alias Spigot.{Types, Transport}
  alias Sippet.{URI}

  @moduledoc """
    Spigot is the main interface for bringing up and querying the system

    Spigot starts it's own Dynamic supervisor (this module), then provides
    a way to start transports that are associated with your UserAgent module

    Spigot also takes most of it's concepts directly from the underlying
    Sippet library, but has been modified to allow associating many socket
    transports with the same UserAgent module.
  """

  @type transport :: :udp | :tcp | :tls | :ws | :wss

  @type transport_options :: [
          address: Types.address(),
          port: :inet.port_number(),
          proxy: binary() | URI.t()
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

    socket = :"#{address}:#{port}/#{transport}"

    options =
      options
      |> Keyword.put_new(:ip, ip)
      |> Keyword.put_new(:family, family)
      |> Keyword.put_new(:port, port)
      |> Keyword.put(:socket, socket)
      |> Keyword.put(:user_agent, user_agent)

    if is_nil(get_transports()) do
      Process.put(:transports, [socket])
    else
      Process.put(:transports, List.insert_at(get_transports(), length(get_transports()), socket))
    end

    setup_transport(transport, options)
    |> Enum.each(fn child -> DynamicSupervisor.start_child(__MODULE__, child) end)
  end

  def get_transports(), do: Process.get(:transports)

  defp setup_transport(transport, options) do
    mod =
      case transport do
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

  def transports() do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.filter(fn {:undefined, _pid, type, [_MODULE]} = match ->
      if type == :worker, do: match
    end)
  end

end
