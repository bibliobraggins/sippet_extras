defmodule Spigot.Transports.WS.Plug do
  @behaviour Plug
  import Plug.Conn
  require Logger

  @impl true
  def init(options) do
    {:ok, options}
  end

  @impl true
  def call(%{request_path: "/", method: "GET"} = conn, options) do
    #["sip"] <- get_req_header(conn, "sec-websocket-protocol") do
      WebSockAdapter.upgrade(conn,
      Spigot.Transports.WS.Server,
      Keyword.put(options, :peer, get_peer_data(conn)),
      timeout: 60_000
    )
  end

end
