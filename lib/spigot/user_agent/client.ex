defmodule Spigot.UserAgent.Client do
  use Task
  alias Sippet.Message, as: Msg
  import Spigot.UserAgent.{Utils}

  def start_link(_method, _uri, _options \\ []) do

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
