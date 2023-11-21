defmodule Sippet.Transports.Utils do

  def resolve_name(host, family) do
    host
    |> String.to_charlist()
    |> :inet.getaddr(family)
  end

  def stringify_sockname(socket) do
    {:ok, {ip, port}} = :inet.sockname(socket)

    address =
      ip
      |> :inet_parse.ntoa()
      |> to_string()

    "#{address}:#{port}"
  end

  def stringify_hostport(host, port) do
    "#{host}:#{port}"
  end

end
