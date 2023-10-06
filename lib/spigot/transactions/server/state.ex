defmodule Spigot.Transactions.Server.State do
  @moduledoc false

  alias Sippet.Message, as: Message
  alias Sippet.Message.RequestLine, as: RequestLine
  alias Spigot.Transactions, as: Transactions

  @typedoc "The server transaction key"
  @type key :: Transactions.Server.Key.t()

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
  Creates the server transaction state.
  """
  def new(
        %Message{start_line: %RequestLine{}} = incoming_request,
        %Transactions.Server.Key{} = key,
        user_agent,
        socket
      )
      when is_atom(user_agent) do
    %__MODULE__{
      request: incoming_request,
      key: key,
      socket: socket,
      user_agent: user_agent
    }
  end
end
