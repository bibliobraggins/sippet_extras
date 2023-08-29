defmodule Spigot.UserAgent do
  require Logger

  alias Sippet.Message, as: Msg
  alias Msg.RequestLine, as: Req
  alias Msg.StatusLine, as: Resp

  @type request :: %Msg{start_line: %Req{}}
  @type response :: %Msg{start_line: %Resp{}}

  defmacro invite(%Msg{start_line: %Req{}} = request, key),
    do: compile(:invite, request, key, __CALLER__)
  defmacro ack(%Msg{start_line: %Req{}} = request, key),
    do: compile(:ack, request, key, __CALLER__)
  defmacro bye(%Msg{start_line: %Req{}} = request, key),
    do: compile(:bye, request, key, __CALLER__)
  defmacro cancel(%Msg{start_line: %Req{}} = request, key),
    do: compile(:cancel, request, key, __CALLER__)
  defmacro refer(%Msg{start_line: %Req{}} = request, key),
    do: compile(:refer, request, key, __CALLER__)
  defmacro register(%Msg{start_line: %Req{}} = request, key),
    do: compile(:register, request, key, __CALLER__)
  defmacro subscribe(%Msg{start_line: %Req{}} = request, key),
    do: compile(:subscribe, request, key, __CALLER__)
  defmacro notify(%Msg{start_line: %Req{}} = request, key),
    do: compile(:notify, request, key, __CALLER__)
  defmacro options(%Msg{start_line: %Req{}} = request, key),
    do: compile(:options, request, key, __CALLER__)
  defmacro info(%Msg{start_line: %Req{}} = request, key),
    do: compile(:info, request, key, __CALLER__)
  defmacro message(%Msg{start_line: %Req{}} = request, key),
    do: compile(:message, request, key, __CALLER__)
  defmacro prack(%Msg{start_line: %Req{}} = request, key),
    do: compile(:prack, request, key, __CALLER__)
  defmacro publish(%Msg{start_line: %Req{}} = request, key),
    do: compile(:publish, request, key, __CALLER__)
  defmacro pull(%Msg{start_line: %Req{}} = request, key),
    do: compile(:pull, request, key, __CALLER__)
  defmacro push(%Msg{start_line: %Req{}} = request, key),
    do: compile(:push, request, key, __CALLER__)
  defmacro store(%Msg{start_line: %Req{}} = request, key),
    do: compile(:store, request, key, __CALLER__)
  defmacro update(%Msg{start_line: %Req{}} = request, key),
    do: compile(:update, request, key, __CALLER__)

  def compile(method, request, key, caller) do
    quote do
      unquote(method)(unquote(request), unquote(key))
    end
  end

  defp wrap_function_do(body) do
    quote do
      fn var!(conn), var!(opts) ->
        _ = var!(opts)
        unquote(body)
      end
    end
  end

  defmacro __before_compile__(_) do
    Logger.debug(extract_methods(__CALLER__.module))
    quote do
    end
  end

  defp extract_methods(user_module) do
    user_module
    |> Module.get_attribute(:__info__)
  end

  def extract_guards({:when, _, [_, guards]}), do: guards

  defmacro __using__(_) do
    quote do
      import Spigot.UserAgent
      @before_compile Spigot.UserAgent

      def receive_request(%Msg{start_line: %Req{method: method}} = request, key) do
      end

      defp do_send_resp(%Msg{start_line: %Resp{}} = resp),
        do: Sippet.send(__MODULE__, resp)

      def send_resp(%Msg{start_line: %Resp{}} = resp),
        do: do_send_resp(resp)

      def send_resp(%Msg{start_line: %Req{}} = req, status),
        do: Msg.to_response(req, status) |> do_send_resp()

      def send_resp(%Msg{start_line: %Req{}} = req, status, reason) when is_binary(reason),
        do: Msg.to_response(req, status, reason) |> do_send_resp()

      use Supervisor

      def start_link(options) when is_list(options) do
        Supervisor.start_link(__MODULE__, options)
      end

      @impl true
      def init(options) do
        children = [
          {Registry,
           name: __MODULE__.ClientRegistry, keys: :unique, partitions: System.schedulers_online()},
          {DynamicSupervisor, strategy: :one_for_one, name: __MODULE__.ClientSupervisor}
        ]

        with {:ok, ua_sup} <- Supervisor.init(children, strategy: :one_for_one) do
          Sippet.register_core(__MODULE__, __MODULE__)
          {:ok, ua_sup}
        else
          reason ->
            raise("#{inspect(reason)}")
        end
      end

    end
  end

  ## build children here

  ## TODO: write out DSL for validation and SIP header/body manipulation
end
