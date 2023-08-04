defmodule SipRouter do
  alias Sippet.Message, as: MSG
  alias MSG.RequestLine, as: REQ
  alias MSG.StatusLine, as: RESP

  defmacro __using__(_opts) do
    quote location: :keep do
      import SipRouter
      use Sippet.Core

      #["ACK", "BYE", "CANCEL", "INFO", "INVITE", "MESSAGE", "NOTIFY", "OPTIONS",
      #"PRACK", "PUBLISH", "PULL", "PUSH", "REFER", "REGISTER", "STORE", "SUBSCRIBE",
      #"UPDATE"]

      defmacro ack(msg, key \\ nil), do: compile(:ack, msg, key, __CALLER__)
      defmacro bye(msg, key), do: compile(:bye, msg, key, __CALLER__)
      defmacro cancel(msg, key), do: compile(:cancel, msg, key, __CALLER__)
      defmacro info(msg, key), do: compile(:info, msg, key, __CALLER__)
      defmacro invite(msg, key), do: compile(:invite, msg, key, __CALLER__)
      defmacro message(msg, key), do: compile(:message, msg, key, __CALLER__)
      defmacro notify(msg, key), do: compile(:notify, msg, key, __CALLER__)
      defmacro options(msg, key), do: compile(:options, msg, key, __CALLER__)
      defmacro prack(msg, key \\ nil), do: compilet(:prack, msg, key, __CALLER__)
      defmacro publish(msg, key \\ nil), do: compilet(:publish, msg, key, __CALLER__)
      defmacro pull(msg, key \\ nil), do: compilet(:pull, msg, key, __CALLER__)
      defmacro push(msg, key \\ nil), do: compilet(:push, msg, key, __CALLER__)
      defmacro refer(msg, key \\ nil), do: compilet(:refer, msg, key, __CALLER__)
      defmacro register(msg, key), do: compile(:register, msg, key, __CALLER__)
      defmacro store(msg, key \\ nil), do: compilet(:store, msg, key, __CALLER__)
      defmacro subscribe(msg, key), do: compile(:subscribe, msg, key, __CALLER__)
      defmacro update(msg, key \\ nil), do: compilet(:update, msg, key, __CALLER__)

      def __route__(method, guards, options) do
        {method, guards} = build_methods(List.wrap(method || options[:via]), guards)
        {quote(do: conn), method, guards, options}
      end

      defp build_methods([], guards) do
        {quote(do: _), guards}
      end

      defp build_methods(methods, guards) do
        var = quote do: method
        guards = join_guards(quote(do: unquote(var) in unquote(methods)), guards)
        {var, guards}
      end

      defp join_guards(fst, true), do: fst
      defp join_guards(fst, snd), do: quote(do: unquote(fst) and unquote(snd))

      @doc false
      def receive_request(%MSG{start_line: %REQ{}} = msg, key) do
        Kernel.apply(__CALLER__, msg.start_line.method, msg, key)
      end

      @doc false
      def receive_response(incoming_response, client_key) do
        raise "attempted to call Core but no receive_response/2 was provided"
      end

      @doc false
      def receive_error(reason, client_or_server_key) do
        raise "attempted to call Core but no receive_error/2 was provided"
      end

      defoverridable receive_request: 2,
                      receive_response: 2,
                      receive_error: 2
      end
  end

  defmacro __before_compile__(env) do
    unless Module.defines?(env.module, {:do_match, 4}) do
      raise "no routes defined in module #{inspect(env.module)} using Sippet.PlugRouter"
    end

    router_to = Module.get_attribute(env.module, :plug_router_to)
    init_mode = Module.get_attribute(env.module, :plug_builder_opts)[:init_mode]

    defs =
      for {callback, {mod, opts}} <- router_to do
        if init_mode == :runtime do
          quote do
            defp unquote(callback)(conn, _opts) do
              unquote(mod).call(conn, unquote(mod).init(unquote(Macro.escape(opts))))
            end
          end
        else
          opts = mod.init(opts)

          quote do
            defp unquote(callback)(conn, _opts) do
              require unquote(mod)
              unquote(mod).call(conn, unquote(Macro.escape(opts)))
            end
          end
        end
      end

    quote do
      unquote_splicing(defs)
      import __MODULE__, only: []
    end
  end

end
