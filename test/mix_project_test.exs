defmodule ExCrap.MixProjectTest do
  use ExUnit.Case, async: true

  test "precommit runs test.crap before boundary spec check" do
    aliases = ExCrap.MixProject.project() |> Keyword.fetch!(:aliases)

    assert Keyword.fetch!(aliases, :precommit) == ["test.crap", "boundary.spec.check"]
  end

  test "boundary spec check runs in test environment from CLI aliases" do
    preferred_envs = ExCrap.MixProject.cli() |> Keyword.fetch!(:preferred_envs)

    assert Keyword.fetch!(preferred_envs, :precommit) == :test
    assert Keyword.fetch!(preferred_envs, :"test.crap") == :test
    assert Keyword.fetch!(preferred_envs, :"boundary.spec.check") == :test
  end
end
