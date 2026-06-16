defmodule ExCrap.MixProjectTest do
  use ExUnit.Case

  test "precommit runs format before test.crap, boundary spec check, and credo" do
    aliases = ExCrap.MixProject.project() |> Keyword.fetch!(:aliases)

    assert Keyword.fetch!(aliases, :precommit) == [
             "format",
             "test.crap",
             "boundary.spec.check",
             "credo --strict"
           ]
  end

  test "test.crap runs coverage, coverage report, and crap score checks" do
    aliases = ExCrap.MixProject.project() |> Keyword.fetch!(:aliases)

    assert Keyword.fetch!(aliases, :"test.crap") == [
             "test --cover --export-coverage default",
             "test.coverage",
             "crap"
           ]
  end

  test "boundary spec check runs in test environment from CLI aliases" do
    preferred_envs = ExCrap.MixProject.cli() |> Keyword.fetch!(:preferred_envs)

    assert Keyword.fetch!(preferred_envs, :precommit) == :test
    assert Keyword.fetch!(preferred_envs, :"test.crap") == :test
    assert Keyword.fetch!(preferred_envs, :"boundary.spec.check") == :test
    assert Keyword.fetch!(preferred_envs, :credo) == :test
  end

  test "application config starts coverage tools for dev and test usage" do
    applications = ExCrap.MixProject.application() |> Keyword.fetch!(:extra_applications)

    assert applications == [:logger, :tools]
  end

  test "published Hex package excludes internal Boundary maintenance files" do
    package_dir =
      Path.join(System.tmp_dir!(), "ex_crap_hex_package_#{System.unique_integer([:positive])}")

    try do
      {output, status} =
        System.cmd("mix", ["hex.build", "--unpack", "--output", package_dir],
          cd: File.cwd!(),
          stderr_to_stdout: true
        )

      assert status == 0, output

      refute File.exists?(Path.join(package_dir, "lib/ex_crap/boundary_spec.ex"))
      refute File.exists?(Path.join(package_dir, "lib/mix/tasks/boundary/spec/check.ex"))
      refute File.exists?(Path.join(package_dir, "lib/mix/tasks/boundary/spec/accept.ex"))
      refute File.exists?(Path.join(package_dir, "priv/boundary_spec.txt"))

      assert File.regular?(Path.join(package_dir, "lib/mix/tasks/crap.ex"))
    after
      File.rm_rf!(package_dir)
    end
  end
end
