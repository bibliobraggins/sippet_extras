defmodule Spile do
  @moduledoc """
  Documentation for `Spile`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Spile.hello()
      :world

  """
  def demo(transport) do
    alias Sippet.Transports.TCP, as: TCP
    alias Sippet.Transports.UDP, as: UDP

    transport =
      case transport do
        :tcp -> TCP
        :udp -> UDP
        unsupported ->
          raise "transport option rejected: #{inspect(unsupported)}"
      end

    with {:ok, _pid} <- Sippet.start_link(name: :test),
         {:ok, _pid} <- transport.start_link(name: :test, port: 5060) do
      build_core([name: :test])
    else
      reason ->
        raise "couldn't start test stack: reason #{inspect(reason)}"
    end
  end

  defp build_core(opts) do
    module = :"#{opts[:name]}.CORE"
    defmodule module do
      require Logger

      @opts opts

      require Logger
      use Spile.Router, [name: @opts[:name]]

      def register(req, _key) do
        Logger.debug(to_string(req))
        send_resp(req, 200)
      end
    end
    Sippet.register_core(opts[:name], module)
  end
end
