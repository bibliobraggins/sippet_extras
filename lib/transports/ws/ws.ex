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
  import Plug.Conn
  @behaviour Plug

  require Logger

  def start_link(options) do
    name =
      case Keyword.fetch(options, :name) do
        {:ok, name} when is_atom(name) ->
          name

        {:ok, other} ->
          raise ArgumentError, "expected :name to be an atom, got: #{inspect(other)}"

        :error ->
          raise ArgumentError, "expected :name option to be present"
      end

    port =
      case Keyword.fetch(options, :port) do
        {:ok, port} when is_integer(port) and port > 0 and port < 65536 ->
          port

        {:ok, other} ->
          raise ArgumentError,
                "expected :port to be an integer between 1 and 65535, got: #{inspect(other)}"

        :error ->
          4000
      end

    {address, family} =
      case Keyword.fetch(options, :address) do
        {:ok, {address, family}} when family in [:inet, :inet6] and is_binary(address) ->
          {address, family}

        {:ok, address} when is_binary(address) ->
          {address, :inet}

        {:ok, other} ->
          raise ArgumentError,
                "expected :address to be an address or {address, family} tuple, got: " <>
                  "#{inspect(other)}"

        :error ->
          {"0.0.0.0", :inet}
      end

    ip =
      case resolve_name(address, family) do
        {:ok, ip} ->
          ip

        {:error, reason} ->
          raise ArgumentError,
                ":address contains an invalid IP or DNS name, got: #{inspect(reason)}"
      end

    websocket_options =
      case Keyword.fetch(options, :websocket_options) do
        {:ok, opts} when is_list(opts) ->
          opts

        _ ->
          []
      end

    {scheme, _tls_options} =
      with {:ok, tls_opts} when is_list(tls_opts) <- Keyword.fetch(options, :tls_options) do
        ## get cipher, key, cert...
        {:https, tls_opts}
      else
        _ ->
          {:http, []}
      end

    children = [
      {
        Bandit,
        plug: {__MODULE__, name: name},
        scheme: scheme,
        ip: ip,
        port: port,
        websocket_options: websocket_options
      }
    ]

    Supervisor.start_link(children, strategy: :one_for_all)
  end

  @impl true
  def init(options) do
    Sippet.register_transport(options[:name], :ws, true)
    {:ok, options}
  end

  @impl true
  def call(conn = %{request_path: "/", method: "GET"}, _options) do
    update_resp_header(conn, "sec-websocket-protocol", "", fn _ -> "sip" end)
    |> WebSockAdapter.upgrade(
      Spigot.Transports.WS.Server,
      [peer: Plug.Conn.get_peer_data(conn)],
      timeout: 60_000
    )
  end

  @not_found Enum.random(["bubkis", "zilch", "nada", "got nothin\'", "*crickets*", "Not Found"])
  @impl true
  def call(conn, _opts), do: send_resp(conn, 404, @not_found)

  defp resolve_name(host, family) do
    host
    |> String.to_charlist()
    |> :inet.getaddr(family)
  end
end
