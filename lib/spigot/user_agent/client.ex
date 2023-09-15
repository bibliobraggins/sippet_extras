defmodule Spigot.UserAgent.Client do
  use GenServer
  alias Sippet.Message, as: Msg
  import Spigot.UserAgent.{Utils}

  @moduledoc """
    This is a default client implementation, but we should put an option in the useragent
    for specifying your own process/handler

    We must at least have a method and uri available to initially construct a message

    All other parameters should be provided in the options list:
      body: an expression that yields a UTF8 string of a body
        - examples:
          - SDP media descriptions (RFC3261)
          - BLF XML requests (RFC3265)
          - SMS chardata (SIP SIMPLE Messages)
  """

  require Logger

  def start_link({user_agent, method, options}) do
    GenServer.start_link(
      __MODULE__,
      {user_agent, method, options[:client_options]},
      options[:genserver_options]
    )
  end

  @impl true
  def init({user_agent, method, options}) do
    timeout =
      Keyword.get(options, :timeout, 36_0000)

    schedule(timeout)

    {:ok, {user_agent, method, options}}
  end

  @impl true
  def handle_info(:send_msg, {user_agent, method, options}) do
    Sippet.Message.build_request(method, options[:uri])
    |> inspect()
    |> Logger.debug()

    {:noreply, {user_agent, method, options}}
  end

  defp schedule(timeout) when is_integer(timeout),
    do: Process.send_after(self(), :send_msg, timeout)

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
