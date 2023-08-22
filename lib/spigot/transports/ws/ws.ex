defmodule Spigot.Transports.WS do
  @moduledoc """
    Below is an example of a WebSocket handshake in which the client
    requests the WebSocket SIP subprotocol support from the server:

      GET / HTTP/1.1
      Host: sip-ws.example.com
      Upgrade: websocket
      Connection: Upgrade
      Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
      Origin: http://www.example.com
      Sec-WebSocket-Protocol: sip
      Sec-WebSocket-Version: 13

    The handshake response from the server accepting the WebSocket SIP
    subprotocol would look as follows:

      HTTP/1.1 101 Switching Protocols
      Upgrade: websocket
      Connection: Upgrade
      Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
      Sec-WebSocket-Protocol: sip

    Once the negotiation has been completed, the WebSocket connection is
    established and can be used for the transport of SIP requests and
    responses.  Messages other than SIP requests and responses MUST NOT
    be transmitted over this connection.

    A SIP WebSocket Client MUST be ready to add a session cookie when
    it runs in a web browser (or behaves like a browser navigating a
    website) and has previously retrieved a session cookie from the
    web server whose URL domain matches the domain in the WebSocket
    URI.  This mechanism is defined by [RFC6265].

    Alice    (SIP WSS)    proxy.example.com
    |                            |
    | HTTP GET (WS handshake) F1 |
    |--------------------------->|
    | 101 Switching Protocols F2 |
    |<---------------------------|
    |                            |
    | REGISTER F3                |
    |--------------------------->|
    | 200 OK F4                  |
    |<---------------------------|
    |                            |

    The following list exposes mandatory-to-implement and optional
    mechanisms for SIP WebSocket Clients and Servers in order to get
    interoperability at the WebSocket authentication level:

    o  A SIP WebSocket Client MUST be ready to be challenged with an HTTP
        401 status code [RFC2617] by the SIP WebSocket Server when
        performing the WebSocket handshake.

    o  A SIP WebSocket Client MAY use TLS client authentication (when in
        a secure WebSocket connection) as an optional authentication
        mechanism.
        Note, however, that TLS client authentication in the WebSocket
        protocol is governed by the rules of the HTTP protocol rather
        than the rules of SIP.

    o  A SIP WebSocket Server MUST be ready to read session cookies when
        present in the WebSocket handshake request and use such a cookie
        value for determining whether the WebSocket connection has been
        initiated by an HTTP client navigating a website in the same
        domain (or subdomain) as the SIP WebSocket Server.

    o  A SIP WebSocket Server SHOULD be able to reject a WebSocket
        handshake request with an HTTP 401 status code by providing a
        Basic/Digest challenge as defined for the HTTP protocol.


  """
  alias Sippet.Message, as: Message
  alias Message.RequestLine, as: Request
  alias Message.StatusLine, as: Response

  use GenServer

  @enforce_keys [
    :name,
    :ip,
    :port,
    :family,
    :scheme,
    :websocket_options,
    :tls_options,
    :connections
  ]

  defstruct @enforce_keys

  require Logger

  def start_link(options) do
    name =
      case Keyword.fetch(options, :name) do
        {:ok, name} when is_atom(name) ->
          name

        {:ok, other} ->
          raise ArgumentError, "expected :name to be an atom, got: #{inspect(other)}"

        :error ->
          raise ArgumentError, "expected :name option to be present"
      end

    port =
      case Keyword.fetch(options, :port) do
        {:ok, port} when is_integer(port) and port > 0 and port < 65536 ->
          port

        {:ok, other} ->
          raise ArgumentError,
                "expected :port to be an integer between 1 and 65535, got: #{inspect(other)}"

        :error ->
          4000
      end

    {address, family} =
      case Keyword.fetch(options, :address) do
        {:ok, {address, family}} when family in [:inet, :inet6] and is_binary(address) ->
          {address, family}

        {:ok, address} when is_binary(address) ->
          {address, :inet}

        {:ok, other} ->
          raise ArgumentError,
                "expected :address to be an address or {address, family} tuple, got: " <>
                  "#{inspect(other)}"

        :error ->
          {"0.0.0.0", :inet}
      end

    ip =
      case resolve_name(address, family) do
        {:ok, ip} ->
          ip

        {:error, reason} ->
          raise ArgumentError,
                ":address contains an invalid IP or DNS name, got: #{inspect(reason)}"
      end

    websocket_options =
      case Keyword.fetch(options, :websocket_options) do
        {:ok, opts} when is_list(opts) ->
          opts

        _ ->
          []
      end

    {scheme, tls_options} =
      with {:ok, tls_opts} when is_list(tls_opts) <- Keyword.fetch(options, :tls_options) do
        ## get cipher, key, cert...
        {:https, tls_opts}
      else
        _ ->
          {:http, []}
      end

    connections =
      :ets.new(:"#{name}_connections", [
        :named_table,
        :set,
        :public,
        {:write_concurrency, true}
      ])

    GenServer.start_link(__MODULE__,
      name: name,
      ip: ip,
      port: port,
      family: family,
      scheme: scheme,
      websocket_options: websocket_options,
      connections: connections,
      tls_options: tls_options
    )
  end

  @impl GenServer
  def init(options) do
    {:ok, nil, {:continue, options}}
  end

  @spec key(:inet.ip_address(), 0..65535) :: binary
  def key(ip, port), do: :erlang.term_to_binary({ip, port})

  @spec connect(atom | :ets.tid(), binary | map, pid | atom) :: boolean
  def connect(connections, peer = %{address: _, port: _, ssl_cert: _}, handler),
    do: connect(connections, key(peer.address, peer.port), handler)

  def connect(connections, key, handler) when is_binary(key),
    do: :ets.insert(connections, {key, handler})

  @spec disconnect(atom | :ets.tid(), map | binary) :: true
  def disconnect(connections, peer = %{address: _, port: _, ssl_cert: _}),
    do: disconnect(connections, key(peer.address, peer.port))

  def disconnect(connections, key) when is_binary(key),
    do: :ets.delete(connections, key)

  @spec lookup_conn(atom | :ets.tid(), binary()) :: [tuple]
  def lookup_conn(connections, key),
    do: :ets.lookup(connections, key)

  def lookup_conn(connections, host, port),
    do: :ets.lookup(connections, key(host, port))

  defp lookup_and_send(connections, to_host, to_port, family, message, key) do
    with {:ok, to_ip} <- resolve_name(to_host, family) do
      case lookup_conn(connections, to_ip, to_port) do
        [{_key, handler}] when is_pid(handler) ->
          send(handler, {:send_message, message})

        [] ->
          nil
          # DynamicSupervisor.start_child(state[:clients], )
      end
    else
      error ->
        Logger.error("problem sending message #{inspect(key)}, reason: #{inspect(error)}")
    end
  end

  @impl GenServer
  def handle_continue(options, nil) do
    children = [
      {
        Bandit,
        plug: Spigot.Transports.WS.Plug,
        scheme: options[:scheme],
        ip: options[:ip],
        port: options[:port],
        websocket_options: options[:websocket_options]
      }
    ]

    with {:ok, _supervisor} <- Supervisor.start_link(children, strategy: :one_for_all),
         :ok <- Sippet.register_transport(options[:name], :tcp, true) do
      Logger.debug(
        "#{inspect(self())} started transport #{stringify_sockname(options[:ip], options[:port])}/ws"
      )

      {:noreply, struct(__MODULE__, options)}
    else
      error ->
        Logger.error("could not start tcp socket, reason: #{inspect(error)}")
        Process.sleep(5_000)
        {:noreply, nil, {:continue, options}}
    end
  end

  @impl GenServer
  def handle_call(
        {:send_message, %Message{start_line: %Request{}} = _message, _to_host, _to_port, _key},
        _from,
        state
      ) do
    # if the message is a request and we have no pid available for a given peer,
    # we spawn a Client GenServer that spawns a socket in active mode for the
    # transaction.

    # lookup_conn(state[:connections], to_host, to_port)

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(
        {:send_message, %Message{start_line: %Response{}} = message, to_host, to_port, key},
        _from,
        state
      ) do
    # if the message is a request and we have no pid available for a given peer,
    # we spawn a Client GenServer that spawns a socket in active mode for the
    # transaction.
    lookup_and_send(state[:connections], to_host, to_port, state[:family], message, key)

    {:reply, :ok, state}
  end

  def resolve_name(host, family) do
    host
    |> String.to_charlist()
    |> :inet.getaddr(family)
  end

  def stringify_sockname(ip, port) do
    address =
      ip
      |> :inet_parse.ntoa()
      |> to_string()

    "#{address}:#{port}"
  end
end
