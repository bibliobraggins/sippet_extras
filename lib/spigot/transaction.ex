defmodule Spigot.Transaction do
  alias Spigot.Types

  alias Sippet.Message, as: SIP
  alias SIP.RequestLine, as: Request
  alias SIP.StatusLine, as: Response

  @moduledoc """
    Transforms will be used to manipulate the headers
    and body parameters of a sip message based on the
    users implementation.

    We should be able to declare the constraints we wish to have,
    the UserAgent should apply the transform that is defined for that
    request as it passes it on to the next Agent.
  """

  @type origin :: %{
          host: binary | charlist | :inet.ip_address()
        }

  @type t :: %__MODULE__{
          request: Types.request(),
          provisional: [Types.response()],
          final: Types.response(),
          origin: origin
        }

  @enforce_keys [
    :request
  ]

  defstruct @enforce_keys ++
              [
                :origin,
                :provisional,
                :final
              ]

  @type transaction() :: t()

  @callback request(
              method :: String.t() | atom(),
              Types.headers(),
              body :: binary() | nil
            ) :: {:ok, transaction(), Types.message_ref()} | {:error, term()}

  @callback open?(transaction(), :read | :write | :read_write) :: boolean()

  @callback recv(transaction(), bytes_size :: non_neg_integer(), timeout()) ::
              {:ok, transaction(), [Types.response()]}
              | {:error, reason :: binary() | atom(), transaction(), [Types.response()]}

  @callback close(transaction()) :: {:ok, transaction()}

  @callback controlling_process(transaction(), pid()) :: {:ok, transaction()} | {:error, term()}

  # -- # -- # -- #

  @spec new(Sippet.Message.t()) :: t()
  def new(%SIP{start_line: %Request{}} = request), do: struct(__MODULE__, request: request)

  @spec put_response(transaction(), Sippet.Message.t()) ::
          {:error, transaction()} | {:ok, transaction()}
  def put_response(transaction, %SIP{start_line: %Response{status_code: status_code}} = response) do
    cond do
      status_code in [100..199] ->
        put_provisional(transaction, response)

      status_code in [200..999] ->
        put_final(transaction, response)
    end
  end

  def put_provisional(transaction, response) when is_list(transaction.provisionals) do
    provisionals =
      transaction.provisionals
      |> List.insert_at(length(transaction.provisionals), response)

    {:ok, %{transaction | provisionals: provisionals}}
  end

  def put_final(transaction, response) do
    case Map.has_key?(transaction, :final) do
      false ->
        {:ok, %{transaction | final: response}}

      true ->
        {:error, transaction}
    end
  end
end
