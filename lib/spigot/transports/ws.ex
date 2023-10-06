defmodule Spigot.Transports.WS do
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

  alias Spigot.Connections

  def child_spec(options) do
    plug =
      Keyword.get(options, :plug, {Spigot.Transports.WS.Plug, user_agent: options[:user_agent]})

    scheme = Keyword.get(options, :scheme, :http)

    options =
      options
      |> Keyword.put(:plug, plug)
      |> Keyword.put(:scheme, scheme)

    %{
      id: options[:socket_name],
      start: {__MODULE__, :start_link, [options]}
    }
  end

  def start_link(options) do
    options = Keyword.put(options, :connections, Connections.init(options[:socket_name]))

    GenServer.start_link(__MODULE__, options, name: options[:socket_name])
  end

  @impl true
  def init(options) do
    Bandit.start_link(
      plug: options[:plug],
      scheme: options[:scheme],
      ip: options[:ip],
      port: options[:port]
    )

    Logger.info("started transport: #{inspect(options[:socket_name])}")

    {:ok, Keyword.put(options, :connections, options)}
  end

  @impl true
  def handle_call({:send_message, _message, _to_host, _to_port, _key}, _from, state) do

    {:reply, :ok, state}
  end

  def close(pid) do
    Process.exit(pid, :shutdown)

    :ok
  end
end
