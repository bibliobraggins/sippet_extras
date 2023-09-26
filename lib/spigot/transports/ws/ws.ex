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

  @enforce_keys [
    :name,
    :ip,
    :port,
    :family,
    :scheme,
    :websocket_options,
    :tls_options,
    :connections
  ]

  @behaviour Spigot.Transport

  defstruct @enforce_keys

  require Logger

  @impl Spigot.Transport
  def build_options(opts) do
    port = Keyword.get(opts, :port, 4000)
    plug = Keyword.get(opts, :plug, {Spigot.Transports.WS.Plug, user_agent: opts[:user_agent]})
    scheme = Keyword.get(opts, :scheme, :http)

    opts =
      opts
      |> Keyword.put_new(:port, port)
      |> Keyword.put_new(:plug, plug)
      |> Keyword.put_new(:scheme, scheme)

    {__MODULE__, opts}
  end

  @impl Spigot.Transport
  def listen(opts) do

    Bandit.start_link(
      plug: opts[:plug],
      scheme: opts[:scheme],
      ip: opts[:ip],
      port: opts[:port]
    )
  end

  @impl true
  def send_message(message, pid, _opts) do
    send({:send_message, message}, pid)
  end

  @impl true
  def close(pid) do
    Process.exit(pid, :shutdown)
    :ok
  end
end
