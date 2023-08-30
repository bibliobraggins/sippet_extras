defmodule Spigot.UserAgent do
  defmacro __using__(options) do
    IO.inspect(options)

    quote do
      alias Spigot.Types

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
          {:ok, ua_sup}
        else
          reason ->
            {:error, inspect(reason)}
        end
      end

      def receive_request(conn) do
      end
    end
  end
end
