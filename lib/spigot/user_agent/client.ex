defmodule Spigot.UserAgent.Client do
  use Task
  alias Sippet.Message, as: Msg
  import Spigot.UserAgent.{Utils}

  @enforce_keys [
    :sip_user,
    :sip_password,
    # shorthand for upstream server domain - SIP is full of terms that are very overloaded
    :realm,
    #
    :require_register
  ]

  defstruct @enforce_keys

  @moduledoc """
    This is a default client implementation, but we should put an option in the useragent
    for specifying your own process/handler

    we must at least have a method and uri available to initially construct a message

          all other parameters should be provided in the options list:
            body: an expression that yields a UTF8 string of a body
              - examples:
                - SDP media descriptions (RFC3261)
                - BLF XML requests (RFC3265)
                - SMS chardata (SIP SIMPLE Messages)
  """
  def start_link(_options \\ []) do
  end

  def build_clients(clients) do
    Enum.into(clients, [], fn {method, uri, options} -> build_client(method, uri, options) end)
  end

  def build_client(method, uri, _client_options \\ []) do
    Msg.build_request(method, uri)
    |> from()
    |> to()
    |> Msg.put_header(:call_id, Msg.create_call_id())
  end
end
