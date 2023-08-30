defmodule Demo do
  use Spigot.UserAgent,
    server: [
      transport: [
        protocol: :tcp,
        address: "192.168.3.104",
        port: 5060
      ],
      handlers: __MODULE__
    ],
    clients: [
      {:register, "sip:100@127.0.0.1", username: "demo_spaghet", password: "92cb159da"}
    ]

  def register(msg) do
    IO.inspect(msg)
  end
end
