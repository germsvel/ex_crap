defmodule Crap.MixProject do
  use Mix.Project

  def project do
    [
      app: :crap,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: [
        {:stream_data, "~> 1.3", only: :test}
      ]
    ]
  end

  def application do
    [extra_applications: [:logger, :tools]]
  end
end
