defmodule Spigot.Transport.WS.Plug do
  @behaviour Plug
  require Logger

  @impl true
  def init(options) do
    options
  end

  @impl true
  def call(%{request_path: "/", method: "GET"} = conn, options) do
    if Plug.Conn.get_req_header(conn, "sec-websocket-protocol") == ["sip"] do
      WebSockAdapter.upgrade(
        conn,
        Spigot.Transport.WS.Server,
        Keyword.put(options, :peer, Plug.Conn.get_peer_data(conn)),
        timeout: 60_000,
        validate_utf8: true
      )
    else
      Plug.Conn.halt(conn)
    end
  end

  @impl true
  def call(conn, _) do
    forbidden(conn)
  end

  def forbidden(conn) do
    Plug.Conn.send_resp(conn, 403, "must be a sip websocket")
  end
end
