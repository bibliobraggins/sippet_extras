defmodule Spigot.Types do
  @moduledoc """
  Types for Spigot SIP Elements
  """

  alias Sippet.Message, as: SIP
  alias SIP.RequestLine, as: Request
  alias SIP.StatusLine, as: Response

  @typedoc """
  a term representing an internet address
  """
  @type address() :: :inet.socket_address() | String.t()
  @typedoc """
  a reference to make each transaction globally unique, be it initiated by us or a peer
  """
  @type message_ref() :: reference()
  @typedoc """
  scheme here is only used to enforce the string on the message itself
  """
  @type scheme :: :sip | :sips
  @typedoc """
  this atom is used to determine transport type and is used in messages from a given UserAgent
  """
  @type transport :: :udp | :tcp | :tls | :ws | :wss
  @typedoc """
  status codes for sip responses
  """
  @type status() :: 100..999
  @typedoc """
  """
  @type headers() :: SIP.headers()
  @typedoc """
  """
  @type request() :: %SIP{start_line: Request}
  @typedoc """
  """
  @type response() :: %SIP{start_line: Response}
  @typedoc """
  """
  @type message() :: iodata()
  @typedoc """
  """
  @type error :: Spigot.TransportError.t() | Spigot.SIPError.t()
  @typedoc """
  """
  @type socket() :: term()
end
