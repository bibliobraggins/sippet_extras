defmodule Spigot.Transports.WS.Client do
  use WebSockex
  require Logger

  def start_link(url, options) do
    WebSockex.start_link(url, __MODULE__, Keyword.put(options, :extra_headers, [{"sec-websocket-protocol", "sip"}]))
  end

  def handle_connect(conn, state) do
    {:ok, Keyword.put(state, :conn, conn)}
  end

  def handle_frame({_type, _msg}, state) do
    {:ok, state}
  end

  def handle_info({:send_message, {_type, _msg} = frame}, state) do
    {:reply, frame, state}
  end

  def terminate(reason, _state) do
    Process.exit(self(), reason)
  end
end
