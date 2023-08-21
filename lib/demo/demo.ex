defmodule Spigot.Demo do
  @user_agent name: :demo

  use Spigot.UserAgent

  require Logger

  def ack(msg, _key) do
    log(msg)
    send_resp(msg, 200)
  end

  def register(msg, _key) do
    log(msg)
    send_resp(msg, 200)
  end

  def invite(msg, _key) do
    log(msg)
    send_resp(msg, 488)
  end

  defp log(msg) do
    Logger.debug("#{__MODULE__}|#{inspect(@user_agent[:name])} Received:\n#{to_string(msg)}")
  end

  def send_options do
    Sippet.Message.build_request(:options, "sip:test@#{@user_agent[:addr]}")
    |> Sippet.Message.put_header(:cseq, {0, :options})
    |> Sippet.Message.put_header(:call_id, Sippet.Message.create_call_id())
    |> Sippet.Message.put_header(
      :from,
      {"test", Sippet.URI.parse!("sip:test@#{@user_agent[:addr]}"),
       %{"tag" => Sippet.Message.create_tag()}}
    )
    |> Sippet.Message.put_header(
      :to,
      {"1000", Sippet.URI.parse!("sip:1000@192.168.3.186:5062"),
       %{"tag" => Sippet.Message.create_tag()}}
    )
    |> Sippet.Message.put_header_front(
      :via,
      {{2, 0}, :tcp, {@user_agent[:addr], 5060}, %{"branch" => Sippet.Message.create_branch()}}
    )
    |> IO.inspect()
  end
end
