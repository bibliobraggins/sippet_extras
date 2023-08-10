defmodule Spigot.UserAgent.Utils do
  alias Sippet.Message, as: Msg
  alias Msg.RequestLine, as: Req
  alias Msg.StatusLine, as: Resp
  alias Sippet.DigestAuth, as: DigestAuth

  @type request :: %Msg{start_line: %Req{}}
  @type response :: %Msg{start_line: %Resp{}}

  # "ACK", "BYE", "CANCEL", "INFO", "INVITE", "MESSAGE", "NOTIFY", "OPTIONS","PRACK", "PUBLISH", "PULL", "PUSH", "REFER", "REGISTER", "STORE", "SUBSCRIBE","UPDATE"

  def methods, do: Enum.into(Msg.known_methods(), [], fn method -> String.downcase(method) |> String.to_existing_atom() end)

  def update_via(message) do
    message
    |> Msg.update_header(:cseq, fn {seq, method} ->
      {seq + 1, method}
    end)
    |> Msg.update_header_front(:via, fn {ver, proto, hostport, params} ->
      {ver, proto, hostport, %{params | "branch" => Msg.create_branch()}}
    end)
    |> Msg.update_header(:from, fn {name, uri, params} ->
      {name, uri, %{params | "tag" => Msg.create_tag()}}
    end)
  end

  @spec authorize(request(), response(), binary(), binary()) :: request()
  def authorize(req, challenge, sip_user, sip_password) do
    {:ok, auth_req} =
      DigestAuth.make_request(
        req,
        challenge,
        fn _ ->
          {:ok, sip_user, sip_password}
        end,
        []
      )
    auth_req
  end

  def challenge(req, status, realm) do
    {:ok, challenge} = DigestAuth.make_response(req, status, realm)
    challenge
  end
end
