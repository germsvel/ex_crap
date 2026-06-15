defmodule ExCrap.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_crap,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      test_ignore_filters: [~r{^test/fixtures/}],
      compilers: [:boundary] ++ Mix.compilers(),
      aliases: [
        doc: "docs",
        "test.crap": [
          "format",
          "test --cover --export-coverage default",
          "test.coverage",
          "crap"
        ],
        precommit: ["test.crap", "boundary.spec.check"],
        mutate:
          "muex --mutators arithmetic,boolean,comparison,conditional,function_call,literal,return_value",
        "mutate.fast":
          "muex --mutators arithmetic,boolean,comparison,conditional,function_call,literal,return_value --optimize-level aggressive --max-per-function 5"
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
    [preferred_envs: [precommit: :test, "test.crap": :test, "boundary.spec.check": :test]]
  end
end
