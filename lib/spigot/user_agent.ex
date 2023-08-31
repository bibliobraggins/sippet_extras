defmodule Spigot.UserAgent do
  #alias Sippet.Message, as: MSG
  alias Sippet.Message
  alias Spigot.Types

  @callback handle_request(Types.request()) :: Types.response()

  @callback handle_response(Types.response()) :: :ok | {:error, term()}

  @methods Enum.each(
             Message.known_methods(),
             fn method ->
               method
               |> String.downcase()
               |> String.to_existing_atom()
             end
           )

  defmacro __using__(_options) do
    quote do
      @behaviour Spigot.UserAgent
      import Spigot.UserAgent

      use Supervisor

      def start_link(options) when is_list(options) do
        Supervisor.start_link(__MODULE__, options)
      end

      @impl Supervisor
      def init(options) do
        children = [
          {Registry,
           name: __MODULE__.ClientRegistry, keys: :unique, partitions: System.schedulers_online()},
          {DynamicSupervisor, strategy: :one_for_one, name: __MODULE__.ClientSupervisor}
        ]

        with {:ok, ua_sup} <- Supervisor.init(children, strategy: :one_for_one) do
          {:ok, ua_sup}
        else
          reason ->
            {:error, inspect(reason)}
        end
      end


      @impl Spigot.UserAgent
      def handle_request(request) do
        if is_integer(__MODULE__.__info__(:functions)[request.start_line.method]) do
          apply(__MODULE__, request.start_line.method, [request])
        else
          Message.to_response(request, 501)
        end
      end

      @impl Spigot.UserAgent
      def handle_response(response) do
        raise("Please define a response handler in #{__MODULE__}")
      end
    end
  end
end
