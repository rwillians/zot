defmodule Zot.MixProject do
  use Mix.Project

  @version "0.6.0"
  @github "https://github.com/rwillians/zot"

  @description """
  A schema parser and validator libary for Elixir.
  """

  def project do
    [
      app: :zot,
      version: @version,
      description: @description,
      source_url: @github,
      homepage_url: @github,
      elixir: ">= 1.17.3",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [debug_info: Mix.env() == :dev],
      build_embedded: Mix.env() not in [:dev, :test],
      aliases: aliases(),
      package: package(),
      docs: [
        main: "Zot",
        source_ref: "v#{@version}",
        source_url: @github,
        canonical: "http://hexdocs.pm/zot/",
        extras: ["LICENSE"]
      ],
      deps: deps(),
      dialyzer: [
        plt_add_apps: [:mix],
        plt_add_deps: :apps_direct,
        flags: [:unmatched_returns, :error_handling, :underspecs],
        plt_core_path: "priv/plts/core",
        plt_local_path: "priv/plts/local"
      ],
      test_coverage: [
        summary: [threshold: 80]
      ]
    ]
  end

  defp package do
    [
      files: ~w(lib mix.exs .formatter.exs README.md LICENSE),
      maintainers: ["Rafael Willians"],
      contributors: ["Rafael Willians"],
      licenses: ["MIT"],
      links: %{
        GitHub: @github,
        Changelog: "#{@github}/releases"
      }
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def aliases do
    [
      #
    ]
  end

  def cli do
    [
      #
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.39", only: [:dev, :docs], runtime: false},
      {:decimal, "~> 2.0"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
