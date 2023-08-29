defmodule Demo do
  use Spigot.UserAgent

  @moduledoc """
    @server [
      transport: Spigot.Transports.TCP,
      options: [
        address: "192.168.3.104",
        port: 5060
      ]
    ]

    @client [
      {:register, "sip:100@127.0.0.1", username: "demo_spaghet", password: "92cb159da"},
    ]
  """

  ack(request)do
    send_resp(request, 501)
  end
end
