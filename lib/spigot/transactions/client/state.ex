defmodule Spigot.Transactions.Client.State do
  @moduledoc false

  alias Sippet.Message, as: Message
  alias Sippet.Message.RequestLine, as: RequestLine
  alias Spigot.Transactions, as: Transactions

  @typedoc "The client transaction key"
  @type key :: Transactions.Client.Key.t()

  @type t :: [
          request: Message.request(),
          key: key,
          user_agent: atom,
          spigot: atom,
          extras: %{}
        ]

  defstruct request: nil,
            key: nil,
            user_agent: nil,
            spigot: nil,
            extras: %{}

  @doc """
  Creates the client transaction state.
  """
  def new(
        %Message{start_line: %RequestLine{}} = outgoing_request,
        %Transactions.Client.Key{} = key,
        user_agent,
        spigot
      )
      when is_atom(spigot) do
    %__MODULE__{
      request: outgoing_request,
      key: key,
      user_agent: user_agent,
      spigot: spigot
    }
  end
end
