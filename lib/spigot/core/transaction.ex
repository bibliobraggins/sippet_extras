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

  @type conn() :: term()

  @callback request(
              method :: String.t() | atom(),
              Types.headers(),
              body :: binary() | nil
            ) :: {:ok, conn(), Types.message_ref()} | {:error, term()}

  @callback open?(conn(), :read | :write | :read_write) :: boolean()

  @callback recv(conn(), bytes_size :: non_neg_integer(), timeout()) ::
              {:ok, conn(), [Types.response()]}
              | {:error, reason :: binary() | atom(), conn(), [Types.response()]}

  @callback close(conn()) :: {:ok, conn()}

  @callback controlling_process(conn(), pid()) :: {:ok, conn()} | {:error, term()}

  # -- # -- # -- #

  @type transform :: function()

  @type t :: %__MODULE__{
          request: Types.request(),
          provisional: [Types.response() | nil],
          final: Types.response() | nil
        }

  def new(%SIP{start_line: %Request{}} = request), do: struct(__MODULE__, request: request)

  def put_response(transaction, %SIP{start_line: %Response{status_code: status_code}} = response) do
    cond do
      status_code in [100..199] ->
        Map.put(transaction, :final, response)

      status_code in [200..999] ->
        Map.put(transaction, :provisional, fn i -> put_provisional(i, response) end)
    end
  end

  defp put_provisional(provisionals, response) when is_list(provisionals),
    do: List.insert_at(provisionals, length(provisionals), response)

  @enforce_keys [
    :request
  ]

  defstruct @enforce_keys ++
              [
                :header_transforms,
                :provisional,
                :final
              ]
end
