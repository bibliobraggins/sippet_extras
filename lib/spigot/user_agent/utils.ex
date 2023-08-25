defmodule Spigot.UserAgent.Utils do
  alias Sippet.Message, as: Msg
  alias Msg.RequestLine, as: Req
  alias Msg.StatusLine, as: Resp
  alias Sippet.DigestAuth, as: DigestAuth

  @type request :: %Msg{start_line: %Req{}}
  @type response :: %Msg{start_line: %Resp{}}

  # "ACK", "BYE", "CANCEL", "INFO", "INVITE", "MESSAGE", "NOTIFY", "OPTIONS","PRACK", "PUBLISH", "PULL", "PUSH", "REFER", "REGISTER", "STORE", "SUBSCRIBE","UPDATE"

  def methods,
    do:
      Enum.into(Msg.known_methods(), [], fn method ->
        String.downcase(method) |> String.to_existing_atom()
      end)

  def from(msg, uri \\ nil, display_name \\ nil) do
    uri =
      if is_nil(uri) do
        case msg do
          %Msg{start_line: %Req{}} ->
            msg.start_line.request_uri

          %Msg{start_line: %Resp{}} ->
            msg.status_line.response_uri
        end
      end

    display_name =
      if is_nil(display_name) do
        ""
      end

    msg
    |> Msg.put_header(:from, {display_name, uri, %{"tag" => Msg.create_tag()}})
  end

  def to(msg, uri \\ nil, display_name \\ nil) do
    uri =
      if is_nil(uri) do
        case msg do
          %Msg{start_line: %Req{}} ->
            msg.start_line.request_uri

          %Msg{start_line: %Resp{}} ->
            msg.status_line.response_uri
        end
      end

    display_name =
      if is_nil(display_name) do
        ""
      end

    msg
    |> Msg.put_header(:to, {display_name, uri, %{"tag" => Msg.create_tag()}})
  end

  def update_via(message) do
    message
    |> Msg.update_header_front(:via, fn {ver, proto, hostport, params} ->
      {ver, proto, hostport, %{params | "branch" => Msg.create_branch()}}
    end)
    |> Msg.update_header(:from, fn {name, uri, params} ->
      {name, uri, %{params | "tag" => Msg.create_tag()}}
    end)
    |> update_cseq()
  end

  def update_cseq(message),
    do: Msg.update_header(message, :cseq, fn {cseq, method} -> {cseq + 1, method} end)

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

  @spec challenge(request, 401 | 407, binary()) :: response
  def challenge(req, status, realm) do
    {:ok, challenge} = DigestAuth.make_response(req, status, realm)
    challenge
  end
end
