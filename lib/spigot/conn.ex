defmodule Spigot.Conn do

  alias Sippet.Message, as: Msg
  alias Msg.RequestLine, as: Request
  alias Msg.StatusLine, as: Response

  @type request :: %Msg{start_line: %Request{}}, Sippet.client_key()
  @type provisional :: %Msg{start_line: %Response{status_code: 1..199}}
  @type final :: %Msg{start_line: %Response{status_code: 200..999}}
  @type responses :: [provisional() | final()]

  @moduledoc """
    Transforms will be used to manipulate the headers
    and body parameters of a sip message based on the
    users implementation.

    We should be able to declare the constraints we wish to have,
    the UserAgent should apply the transform that is defined for that
    request as it passes it on to the next Agent.
  """
  @type transform :: function()

  @type t :: %__MODULE__{
    request: request(),
    responses: responses(),
  }

  @enforce_keys [
    :request,
    :responses
  ]

  defstruct @enforce_keys ++ [
    :header_transforms,
  ]
end
