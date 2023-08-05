defmodule Spigot do
  require Logger
  alias Sippet.Transports.TCP, as: TCP
  alias Sippet.Transports.UDP, as: UDP

  # options = [
  #  :name,
  #  :transport,
  #  :address,
  #  :port,
  #  :family,
  #  :router

  def start(options) do
    router =
      if is_nil(options[:router]) do
        raise "a router module must be provided to build a spigot"
      else
        options[:router]
      end

    transport =
      if is_nil(options[:transport]) do
        raise "a transport module must be provided to build a spigot"
      else
        transport(options[:transport])
      end

    if is_nil(options[:name]) do
      raise "a name must be provided to build a spigot"
    end

    with {:ok, _pid} <- Sippet.start_link(name: options[:name]),
         {:ok, _pid} <- transport.start_link(options),
         :ok <- Sippet.register_core(options[:name], router) do
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
