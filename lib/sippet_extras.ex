defmodule SippetExtras do
  @moduledoc """
  Documentation for `SippetExtras`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> SippetExtras.hello()
      :world

  """
  def test :tcp do
    with {:ok, _pid} <- Sippet.start_link(name: :test),
         {:ok, _pid} <- Sippet.Transports.TCP.start_link(name: :test, port: 5060) do
      build_core(:test)
    else
      reason ->
        raise "couldn't start test stack: reason #{inspect(reason)}"
    end
  end

  defp build_core(name) do
    defmodule :"#{name}.Core" do
      use Sippet.Core
      require Logger

      @name name

      alias Sippet.Message, as: Msg
      alias Msg.RequestLine, as: Request
      alias Msg.StatusLine, as: Response

      @impl true
      def receive_request(%Msg{start_line: %Request{}} = req, _key) do
        Logger.debug("Received|#{inspect(__MODULE__)}|\n#{to_string(req)}")

        Sippet.send(@name, Msg.to_response(req, 200))
      end

      @impl true
      def receive_response(%Msg{start_line: %Response{}} = resp, _client_key) do
        Logger.debug("Received|#{inspect(__MODULE__)}|\n#{to_string(resp)}")
      end

      @impl true
      def receive_error(reason, key) do
        Logger.warning("Error|#{inspect(__MODULE__)}|#{inspect(reason)}|#{inspect(key)}")
      end
    end

    Sippet.register_core(name, :"#{name}.Core")
  end
end
