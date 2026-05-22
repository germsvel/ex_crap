defmodule ExCrap.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_crap,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      compilers: [:boundary] ++ Mix.compilers(),
      aliases: [
        doc: "docs"
      ],
      deps: [
        {:stream_data, "~> 1.3", only: :test},
        {:ex_doc, "~> 0.34", only: :dev, runtime: false},
        {:boundary, "~> 0.10", runtime: false}
      ]
    ]
  end

  def application do
    [extra_applications: [:logger, :tools]]
  end
end
