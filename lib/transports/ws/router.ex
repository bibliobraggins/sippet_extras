defmodule Spigot.Transports.WS.Router do
  use Plug.Router

  require Logger

  plug :match
  plug :dispatch

  get "/" do
    subprotocol = Plug.Conn.get_req_header(conn, "sec-websocket-protocol")

    Plug.Conn.update_resp_header(conn, "sec-websocket-protocol", "", fn _ -> subprotocol end)
    conn
    |> WebSockAdapter.upgrade(Spigot.Transports.WS.Server, [name: :sip], timeout: 10_000)
    |> halt()
  end

end
