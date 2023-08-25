defmodule Spigot do
  use Supervisor

  @moduledoc """
    options = [
      :name,
      :transport,
      :address,
      :port,
      :family,
      :user_agent
  """

  @transports [:udp, :tcp, :tls, :ws, :wss]

  @spec start_link(nil | maybe_improper_list | map) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(options) do
    unless options[:transport] in @transports, do: raise(ArgumentError)

    options =
      if is_nil(options[:address]) do
        Keyword.put(options, :address, "0.0.0.0")
      end

    Code.ensure_loaded(options[:user_agent])

    Supervisor.start_link(__MODULE__, options)
  end

  @impl true
  def init(options) do
    children = [
      {Sippet, name: options[:user_agent]},
      {transport_module(options[:transport]),
       [name: options[:user_agent], address: options[:address], port: options[:port]]},
      {options[:user_agent], options}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def transport_module(id) do
    case id do
      :udp -> Sippet.Transports.UDP
      :tcp -> Spigot.Transports.TCP
      :tls -> Spigot.Transports.TCP
      :ws -> Spigot.Transports.WS
      :wss -> Spigot.Transports.WS
    end
  end
end
