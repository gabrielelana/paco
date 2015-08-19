defmodule Paco.Mixfile do
  use Mix.Project

  def project do
    [app: :paco,
     version: "0.0.1",
     elixir: "> 1.0.2",
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [{:benchfella, "~> 0.2.1", only: :dev},
     {:poison, "~> 1.4.0", only: :dev}]
  end
end
