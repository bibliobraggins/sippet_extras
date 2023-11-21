defmodule Sippet.Transport.WS do
  alias Sippet.Transports.{Utils,Connections}

  @moduledoc """
    Below is an example of a WebSocket handshake in which the client
    requests the WebSocket SIP subprotocol support from the server:

      GET / HTTP/1.1
      Host: sip-ws.example.com
      Upgrade: websocket
      Connection: Upgrade
      Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
      Origin: http://www.example.com
      Sec-WebSocket-Protocol: sip
      Sec-WebSocket-Version: 13

    The handshake response from the server accepting the WebSocket SIP
    subprotocol would look as follows:

      HTTP/1.1 101 Switching Protocols
      Upgrade: websocket
      Connection: Upgrade
      Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
      Sec-WebSocket-Protocol: sip

    Once the negotiation has been completed, the WebSocket connection is
    established and can be used for the transport of SIP requests and
    responses.  Messages other than SIP requests and responses MUST NOT
    be transmitted over this connection.

    A SIP WebSocket Client MUST be ready to add a session cookie when
    it runs in a web browser (or behaves like a browser navigating a
    website) and has previously retrieved a session cookie from the
    web server whose URL domain matches the domain in the WebSocket
    URI.  This mechanism is defined by [RFC6265].

    Alice    (SIP WSS)    proxy.example.com
    |                            |
    | HTTP GET (WS handshake) F1 |
    |--------------------------->|
    | 101 Switching Protocols F2 |
    |<---------------------------|
    |                            |
    | REGISTER F3                |
    |--------------------------->|
    | 200 OK F4                  |
    |<---------------------------|
    |                            |

    The following list exposes mandatory-to-implement and optional
    mechanisms for SIP WebSocket Clients and Servers in order to get
    interoperability at the WebSocket authentication level:

    o  A SIP WebSocket Client MUST be ready to be challenged with an HTTP
        401 status code [RFC2617] by the SIP WebSocket Server when
        performing the WebSocket handshake.

    o  A SIP WebSocket Client MAY use TLS client authentication (when in
        a secure WebSocket connection) as an optional authentication
        mechanism.
        Note, however, that TLS client authentication in the WebSocket
        protocol is governed by the rules of the HTTP protocol rather
        than the rules of SIP.

    o  A SIP WebSocket Server MUST be ready to read session cookies when
        present in the WebSocket handshake request and use such a cookie
        value for determining whether the WebSocket connection has been
        initiated by an HTTP client navigating a website in the same
        domain (or subdomain) as the SIP WebSocket Server.

    o  A SIP WebSocket Server SHOULD be able to reject a WebSocket
        handshake request with an HTTP 401 status code by providing a
        Basic/Digest challenge as defined for the HTTP protocol.


  """

  use GenServer
  require Logger

  def start_link(options) do
    sippet =
      case Keyword.fetch(options, :name) do
        {:ok, sippet} when is_atom(sippet) ->
          sippet

        {:ok, other} ->
          raise ArgumentError, "expected :sippet to be an atom, got: #{inspect(other)}"

        :error ->
          raise ArgumentError, "expected :sippet option to be present"
      end

    scheme = Keyword.get(options, :scheme, :http)
    family = Keyword.get(options, :family, :inet)
    ip =
      Keyword.get(options, :ip, {0,0,0,0})
      |> case do
        ip when is_tuple(ip) ->
          ip
        ip when is_binary(ip) ->
          Utils.resolve_name(ip, family)
        end
    port = Keyword.get(options, :port, 5060)

    plug = {_plug_mod, _plug_options} =
      case Keyword.get(options,:plug,Sippet.Transport.WS.Plug) do
        {plug, plug_options} when is_atom(plug) ->
          {plug, plug_options}
        plug when is_atom(plug) ->
          {plug, sippet: options[:name]}
        _ ->
          {Sippet.Transport.WS.Plug, sippet: options[:name]}
      end

    port_range = Keyword.get(options, :port_range, 10_000..20_000)
    connections_table = Connections.init(options[:sippet])

    client_options = [
      sippet: sippet,
      port_range: port_range,
      connections: connections_table
    ]

    bandit_options =
    []
    |> Keyword.put(:ip, ip)
    |> Keyword.put(:port, port)
    |> Keyword.put(:scheme, scheme)
    |> Keyword.put(:plug, plug)

    options =
      options
      |> Keyword.put(:sippet, sippet)
      |> Keyword.put(:client_options, client_options)
      |> Keyword.put(:bandit_options, bandit_options)

    GenServer.start_link(__MODULE__, options)
  end

  @impl true
  def init(options) do
    Sippet.register_transport(options[:sippet], :ws, true)

    {:ok, nil, {:continue, options}}
  end

  @impl true
  def handle_continue(state, nil) do
    case Bandit.start_link(
      plug: state[:plug],
      scheme: state[:scheme],
      ip: state[:ip],
      port: state[:port]
    ) do
      {:ok, _pid} ->
        Logger.info("started WS transport: #{inspect(self())}")
        {:noreply, state}
      _ = reason ->
          Logger.error(
            "#{state[:ip]}#{state[:port]}/ws" <>
              "#{inspect(reason)}, retrying in 10s..."
          )

          Process.sleep(10_000)

          {:noreply, nil, {:continue, state}}
    end
  end

  @impl true
  def handle_call({:send_message, message, key, {_protocol, host, port}}, _from, state) do
    with {:ok, to_ip} <- Utils.resolve_name(host, state[:family]) do
      case Connections.lookup(state[:connections], to_ip, port) do
        [{_key, handler}] ->
          send(handler, {:send_message, message})

        [] ->
          {:reply, {:error, :not_found}}
      end
    else
      {:error, reason} ->
        Logger.warning("tcp transport error for #{host}:#{port}: #{inspect(reason)}")

        if key != nil do
          Sippet.Router.receive_transport_error(state[:sippet], key, reason)
        end
    end

    {:reply, :ok, state}
  end

  def close(pid) do
    Process.exit(pid, :shutdown)

    :ok
  end
end
