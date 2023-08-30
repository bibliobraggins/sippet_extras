defmodule Spigot.UI.Router do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  def init(options) do
    options
  end

  get "/" do
    Plug.Conn.send_resp(conn, 200, "HELLO!! :D")
  end
end
