defmodule ExCrap.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/germsvel/ex_crap"

  def project do
    [
      app: :ex_crap,
      version: @version,
      elixir: "~> 1.18",
      description: description(),
      package: package(),
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
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

  defp description do
    "Calculate Change Risk Anti-Patterns scores from cyclomatic complexity and test coverage."
  end

  defp package do
    [
      files: [
        "lib/ex_crap.ex",
        "lib/ex_crap/complexity.ex",
        "lib/ex_crap/coverage.ex",
        "lib/ex_crap/mix.ex",
        "lib/ex_crap/report.ex",
        "lib/ex_crap/scanner.ex",
        "lib/ex_crap/score.ex",
        "lib/mix/tasks/crap.ex",
        "mix.exs",
        "README.md",
        "LICENSE.md"
      ],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
