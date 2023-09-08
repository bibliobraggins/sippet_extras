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
        :udp ->
          Sippet.Transports.UDP

        :tcp ->
          Spigot.Transports.TCP

        :tls ->
          Spigot.Transports.TCP

        :ws ->
          Spigot.Transports.WS

        :wss ->
          Spigot.Transports.WS

        _ ->
          raise "must provide a supported transport options"
      end

    Supervisor.start_link(
      __MODULE__,
      {
        transport_module,
        Keyword.merge([user_agent: user_agent], options)
      }
    )
  end

  @impl true
  def init(transport) do
    children = [
      transport
      # {user_agent, options}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
