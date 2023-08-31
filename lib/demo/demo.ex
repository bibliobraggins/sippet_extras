defmodule Demo do
  require Logger
  use Spigot.UserAgent,
    server: %{
      transport: [
        protocol: :tcp,
        address: "192.168.3.104",
        port: 5060
      ]
    },
    clients: [
      %{
        username: "demo_spaghet",
        password: "92cb159da",
        requests: []
      }
    ]

  def register(msg) do
    Logger.info("Request:\n#{to_string(msg)}")
    response = Sippet.Message.to_response(msg, 200)

    Logger.info("Response:\n#{to_string(response)}")
    response
    |> Sippet.Message.to_iodata
  end
end
