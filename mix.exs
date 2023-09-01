defmodule Spigot.MixProject do
  use Mix.Project

  def project do
    [
      app: :spigot,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [
        :logger,
        :observer,
        :wx,
        :runtime_tools
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:sippet, git: "https://github.com/bibliobraggins/elixir-sippet"},
      {:thousand_island, "~> 0.6.7"},
      {:bandit, "~> 0.7.7"},
      {:websock_adapter, "~> 0.5.3"},
      {:httpoison, "~> 2.1"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
