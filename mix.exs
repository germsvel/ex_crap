defmodule ExCrap.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_crap,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      compilers: [:boundary] ++ Mix.compilers(),
      aliases: [
        doc: "docs",
        precommit: [
          "format",
          "test --cover --export-coverage default",
          "test.coverage",
          "crap",
          "muex"
        ]
      ],
      deps: [
        {:stream_data, "~> 1.3", only: :test},
        {:ex_doc, "~> 0.34", only: :dev, runtime: false},
        {:muex, "~> 0.6", only: [:dev, :test], runtime: false},
        {:boundary, "~> 0.10", runtime: false}
      ]
    ]
  end

  def application do
    [extra_applications: [:logger, :tools]]
  end

  def cli do
    [preferred_envs: [precommit: :test]]
  end
end
