defmodule Spigot.UI.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Bandit, plug: LevUi.Router}
    ]

    opts = [strategy: :one_for_one, name: Spigot.UI.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
