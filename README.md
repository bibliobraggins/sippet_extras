# Spigot

Spigot aims to be a Plug style library for SIP applications.

aimed features:
  - off-the-shelf UDP, TCP, TLS, WS, and WSS connection handling that is transaction-aware
  - plug router style DSL for request handling

## Example

```elixir
defmodule MyUserAgent do 
  use Spigot.Router, name: :my_agent
  # define routes
  def register(msg, key) do
    send_resp(msg, 200)
  end
end

Spigot.start(name: :my_agent, port: 5060, transport: :tcp, user_agent: MyUserAgent)
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `Spigot` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:spigot, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/Spigot>.

