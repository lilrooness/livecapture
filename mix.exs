defmodule RtcServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :rtc_server,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {RtcServer, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:cowboy, "~> 2.4"},
      {:plug, "~> 1.7"},
      {:plug_cowboy, "~> 2.0"},
      {:jason, "~> 1.1"},
      {:gen_state_machine, "~> 2.0"},
      {:scramerl, git: "https://github.com/lilrooness/scramerl"},
      {:elixir_make, "~> 0.6.0"}
    ]
  end
end
