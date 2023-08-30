defmodule Spigot.Transports.UDP do
  @behaviour Spigot.Transport

  alias Sippet.Message, as: MSG

  @impl true
  def init(ip, port, opts) do
    family = Keyword.get(opts, :family, :inet)
    active = Keyword.get(opts, :active, :true)

    opts =
      Keyword.merge([family: family, active: active], opts)

    case :gen_udp.open(port, [:binary, {:active, opts[:active]}, {:ip, opts[:ip]}, opts[:family]]) do
      {:ok, socket} ->
        {:ok, socket}
      reason ->
        {:error, reason}
    end
  end

  @impl true
  def send(socket, msg),
    do: :gen_udp.send(socket, MSG.to_iodata(msg))

  @impl true
  def recv(socket, bytes, timeout),
    do: wrap_err(:gen_udp.recv(socket, bytes, timeout))

  @impl true
  def close(socket),
    do: :gen_udp.close(socket)

  defp wrap_err({:error, reason}), do: {:error, inspect(reason)}
  defp wrap_err(other), do: other

end
