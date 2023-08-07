# Spigot

Spigot aims to be a Plug style library for SIP applications.

aimed features:
  - off-the-shelf UDP, TCP, TLS, WS, and WSS connection handling that is transaction-aware
  - plug router style DSL for request handling

## Example

```elixir
defmodule MySipElement do
  use Spigot.Router, options
  # MySipElement.start_link(name: :my_agent, port: 5060, address: "127.0.0.1")

  def start(options) do

    with {:ok, pid} <- Sippet.start_link(name: options[:name]), 
        {:ok, pid} <- Sippet.Transport.TCP.start_link(options) 
        do
          
        else
          reason -> 
            raise "problem "
        end
  end
end

defmodule MyUserAgent do 
  use Spigot.Router, name: my_agent
  # define routes
  def register(msg, key) do
    send_resp(msg, 200)
  end
end
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

