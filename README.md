# Sippet Extras

Sippet Extras is an experimental set of socket transports for an elixir based SIP Element, designed
for coordinating SIP transactions over a network.

About SIP: 

SIP as a protocol is similar to HTTP, with some key differences: 
  - SIP elements may be a client or server depending on if they are the origin or receiver of a message.
  - Elements may be on the public internet or behind a NAT layer
  - Common HTTP requests typically represent a simple request :: response pattern, 
    but with SIP INVITE's in particular, messages may need to be relayed to through
    many "hops" before a final response is received from an accepting party/peer.


A SIP element should at least handle the following  methods as a client and server:
  - INVITE
    - invite's are used to set up one or more rtp session from one peer to another, as a call.
      calls represent a process in memory that will make use of a media pipeline to handle data streams
  - CANCEL
    - cancel is used to deconstruct and disregard a call that was in progress, but the given
      client has not received a final ([2-6]00) response yet. the call should not complete 
      construction and be torn down.
  - BYE
    - same as a cancel, but this call was set up, indicating it should be persisted somewhere in history
      and the call should now be torn down.
  - ACK
    - ack is used to indicate that a client has handled a final response from the server for a given transaction
      in many cases acks won't be provided with a key, but their CSEQ will mach the one sent in the initial invite
  - REFER
    - refer is used to indicate that either a new recipient must be added to an existing call (in the case of a conference)
      or to transfer from one peer to another. Note that this operation can be handled before or upon final response from
      the target peer.
  - REGISTER
    - register is used to tell a SIP network where a peer has connected from, and informs the upstream server how
      to reach a given SIP element.
  - SUBSCRIBE
    - subscribe is used to notify a sip network/server of events that your agent would like to observe.
      see RFC3265 for specific descriptions of events.
  - NOTIFY
    - notify is used to handle events from an peer source,
      some events are explicitly requested via a subscribe request before notify's are sent to the recipient of an event.
  - OPTIONS
    - sip elements can use this request to discover the capabilities of their upstream server/proxy.
      the server usually responds with an "Allow" header indicating what methods the client peer can use with the server.

The core library elixir-sippet provides built-in support for the following as well:
  - INFO
  - MESSAGE
  - PRACK
  - PUBLISH
  - PULL
  - PUSH
  - STORE
  - UPDATE
    
aimed features:
  - off-the-shelf UDP, TCP, TLS, WS, and WSS transports

## Example

```elixir
defmodule MyCore do 
  use Sippet.Core

  def receive_request(request, key) do
    "... do some stuff here ..."
  end

  def receive_response(response, key) do
    "... do some other stuff here ..."
  end
  
end
```

```
iex(1)> Sippet.start_link(name: :sippet_name)
{:ok, #PID<0.251.0>}
iex(2)> Sippet.Transports.TCP.start_link(name: :sippet_name, port: 5060, ip: "127.0.0.1")
[debug] #PID<0.259.0> started transport 127.0.0.1:5060/tcp
iex(3)> Sippet.register_core(:sippet_name, MyCore)
:ok
```
And now whatever you have written in MyCore should be invoked when valid messages arrive on socket.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `SippetExtras` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sippet_extras, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/SippetExtras>.

