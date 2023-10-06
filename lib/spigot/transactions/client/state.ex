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
          socket: atom,
          extras: %{}
        ]

  defstruct request: nil,
            key: nil,
            user_agent: nil,
            socket: nil,
            extras: %{}

  @doc """
  Creates the client transaction state.
  """
  def new(
        %Message{start_line: %RequestLine{}} = outgoing_request,
        %Transactions.Client.Key{} = key,
        user_agent,
        socket
      )
      when is_atom(socket) do
    %__MODULE__{
      request: outgoing_request,
      key: key,
      user_agent: user_agent,
      socket: socket
    }
  end
end
