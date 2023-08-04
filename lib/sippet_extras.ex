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

  defp build_core(opts) do
    module = :"#{opts[:name]}.CORE"
    defmodule module do
      use SipRouter, [name: __MODULE__]
    end
    Sippet.register_core(opts[:name], module)
  end
end
