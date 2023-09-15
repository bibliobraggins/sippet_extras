defmodule Spigot.Transports.TCP do
  @moduledoc """
  Implements a TCP transport via ThousandIsland
  """

  @behaviour Spigot.Transport
  import Spigot.Transport

  require Logger


  # alias Sippet.Message, as: Message
  # alias Message.RequestLine, as: Request
  # alias Message.StatusLine, as: Response

  @doc false
  @impl true
  def build_options(opts) do
    opts =
      opts
      |> Keyword.put_new(:reuseport, true)

    {__MODULE__, opts}
  end

  @doc """
  Starts the TCP transport.
  """
  @impl true
  def listen(opts) do
    case ThousandIsland.start_link(
           port: opts[:port],
           handler_module: Spigot.Transports.TCP.Handler,
           transport_module: opts[:transport_module],
           transport_options: opts[:transport_options],
           handler_options: [user_agent: opts[:user_agent]]
         ) do
      {:ok, pid} ->
        Logger.debug("#{inspect(self())} started transport " <> opts[:sockname])
        {:ok, Keyword.put_new(opts, :socket, pid)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def connect(to_host, to_port, opts) do
    family = get_family(to_host)
      with {:ok, to_ip} <- resolve_name(to_host, family) do
        :gen_tcp.connect(to_ip, to_port, opts)
      else
        error ->
          error
      end
  end


  @impl true
  def send_message(message, pid, _opts) do
    send({:send_message, message}, pid)
  end

  @impl true
  def close(pid, timeout \\ 15000), do: ThousandIsland.stop(pid, timeout)

end
