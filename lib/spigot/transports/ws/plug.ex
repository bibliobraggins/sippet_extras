defmodule Spigot.Transports.WS.Plug do
  @behaviour Plug
  require Logger

  @impl true
  def init(options) do
    options
  end

  @impl true
  def call(%{request_path: "/", method: "GET"} = conn, options) do
    if Plug.Conn.get_req_header(conn, "sec-websocket-protocol") == ["sip"] do
      conn = Plug.Conn.put_resp_header(conn, "sec-websocket-protocol", "sip")
      WebSockAdapter.upgrade(
        conn,
        Spigot.Transports.WS.Server,
        Keyword.put(options, :peer, Plug.Conn.get_peer_data(conn)),
        timeout: 60_000,
        validate_utf8: true
      )
    else
      Plug.Conn.send_resp(conn, 404, "Not Found")
    end
  end

  def call(conn, _options) do
    Plug.Conn.send_resp(conn, 501, "Not Implemented")
  end
end
