defmodule Spigot do
  alias Spigot.{Types, Transport}
  alias Sippet.{URI, Message}
  alias Message.{RequestLine, StatusLine}

  @moduledoc """
    Spigot is the main interface for bringing up and querying the system

    Spigot starts it's own Dynamic supervisor (this module), then provides
    a way to start transports that are associated with your UserAgent module

    Spigot also takes most of it's concepts directly from the underlying
    Sippet library, but has been modified to allow associating many spigot
    transports with the same UserAgent module.
  """

  @type transport :: :udp | :tcp | :tls | :ws | :wss

  @type transport_options :: [
          address: Types.address(),
          port: :inet.port_number(),
          proxy: binary() | URI.t()
        ]

  @type webspigot_options :: [
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

  def start(_, _) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_transport(options) do
    user_agent =
      case Code.ensure_loaded(options[:user_agent]) do
        {:module, module} ->
          module

        {:error, _} = error ->
          raise ArgumentError,
                "must provide a user_agent module: #{inspect(error)}"
      end

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

    spigot = :"#{address}:#{port}/#{transport}"

    options =
      []
      |> Keyword.put(:ip, ip)
      |> Keyword.put(:family, family)
      |> Keyword.put(:port, port)
      |> Keyword.put(:transport, transport)
      |> Keyword.put(:spigot, spigot)
      |> Keyword.put(:user_agent, user_agent)

    transport = setup_transport(options)

    DynamicSupervisor.start_child(__MODULE__, transport)
  end

  def transports() do
    DynamicSupervisor.which_children(__MODULE__)
  end

  def reliable?(%Message{headers: %{via: [via | _]}}) do
    {_version, protocol, _host_and_port, _params} = via

    case protocol do
      :udp ->
        false

      _ ->
        true
    end
  end

  defp setup_transport(options) do
    case options[:transport] do
      :udp ->
        Spigot.Transport.UDP.child_spec(options)

      :tcp ->
        Spigot.Transport.TCP.child_spec(options)

      :tls ->
        Spigot.Transport.TCP.child_spec(options)

      :ws ->
        Spigot.Transport.WS.child_spec(options)

      :wss ->
        Spigot.Transport.WS.child_spec(options)

      _ ->
        raise "must provide a supported transport option"
    end
  end

  def send(user_agent, spigot, message) do
    unless Message.valid?(message) do
      raise ArgumentError, "expected :message argument to be a valid SIP message"
    end

    case message do
      %Message{start_line: %RequestLine{method: :ack}} ->
        Spigot.Router.send_transport_message(spigot, message, nil)

      %Message{start_line: %RequestLine{}} ->
        Spigot.Router.send_transaction_request(user_agent, spigot, message)

      %Message{start_line: %StatusLine{}} ->
        Spigot.Router.send_transaction_response(spigot, message)
    end
  end
end
