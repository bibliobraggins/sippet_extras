defmodule Spigot do
  require Logger

  alias Spigot.Transports.TCP, as: TCP
  alias Spigot.Transports.WS, as: WS

  alias Sippet.Transports.UDP, as: UDP

  # options = [
  #  :name,
  #  :transport,
  #  :address,
  #  :port,
  #  :family,
  #  :user_agent

  @transports [:udp, :tcp, :tls, :ws, :wss]

  def start(options) do
    user_agent =
      if is_nil(options[:user_agent]) do
        raise "a user_agent module must be provided to build a spigot"
      else
        options[:user_agent]
      end

    transport =
      unless options[:transport] in @transports do
        raise "a transport module must be provided to build a spigot"
      else
        transport(options[:transport])
      end

    if is_nil(options[:name]) do
      raise "a name must be provided to build a spigot"
    end

    with {:ok, _sippet} <- Sippet.start_link(name: options[:name]),
         {:ok, _transport} <- transport.start_link(options),
         {:module, _user_agent} <- Code.ensure_loaded(user_agent),
         :ok <- Sippet.register_core(options[:name], user_agent) do
      {:ok, user_agent, options: options}
      :ok
    else
      error -> raise "#{inspect(error)}"
    end
  end

  defp transport(transport) do
    case transport do
      :tcp ->
        TCP

      :udp ->
        UDP

      :ws ->
        WS

      unsupported ->
        raise "transport option rejected: #{inspect(unsupported)}"
    end
  end

  @moduledoc """
  Documentation for `Spigot`.
    def register(req, _key) do
    Logger.debug(to_string(req))
    send_resp(req, 200)
  end
  """
end
