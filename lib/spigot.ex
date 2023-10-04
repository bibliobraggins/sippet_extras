defmodule Spigot do
  use Application

  alias Spigot.{Types, Transport}
  alias Sippet.{URI, Message, Message.RequestLine, Message.StatusLine}

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
    port = Keyword.get(options, :port, 5060)
    transport = Keyword.get(options, :transport, :udp)
    sockname = :"#{address}:#{port}/#{transport}"

    options =
      options
      |> Keyword.put_new(:ip, ip)
      |> Keyword.put_new(:family, family)
      |> Keyword.put_new(:port, port)
      |> Keyword.put(:sockname, sockname)

    children = setup_transport(transport, user_agent, options)

    Enum.each(children, fn child -> DynamicSupervisor.start_child(__MODULE__, child) |> IO.inspect() end)
  end

  defp setup_transport(transport, user_agent, options) do
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

    [spec,
      {Registry,
         name: :"#{user_agent}.Registry", keys: :unique, partitions: System.schedulers_online()},
      {DynamicSupervisor, strategy: :one_for_one, name: :"#{user_agent}.Supervisor"}]
  end

  def transports(), do: DynamicSupervisor.which_children(__MODULE__)

  def send(transport, message) do
    unless Message.valid?(message) do
      raise ArgumentError, "expected :message argument to be a valid SIP message"
    end

    case message do
      %Message{start_line: %RequestLine{method: :ack}} ->
        Spigot.Router.send_transport_message(transport, message, nil)

      %Message{start_line: %RequestLine{}} ->
        Spigot.Router.send_transaction_request(transport, message)

      %Message{start_line: %StatusLine{}} ->
        Spigot.Router.send_transaction_response(transport, message)
    end
  end
end
