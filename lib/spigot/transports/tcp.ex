defmodule Spigot.Transports.Tcp do
  @behaviour Spigot.Transport

  @impl true
  def init(ip, port, opts) do
    family = Keyword.get(opts, :family, :inet)
    active = Keyword.get(opts, :active, :true)
    opts = Keyword.merge([family: family, active: active], opts)

    {ThousandIsland, [
    port: port,
    transport_options: [ip: ip],
    handler_module: Server,
    handler_options: [user_agent: opts[:user_agent]]
    ]
  }
  end

  @impl true
  def connect(ip, port, options) do

  end

end
