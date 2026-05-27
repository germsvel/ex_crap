defmodule Mix.Tasks.CrapTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  describe "task metadata" do
    test "exposes mix task docs" do
      assert Mix.Tasks.Crap.shortdoc() == "Print report-only CRAP scores for project source"

      assert Mix.Tasks.Crap.moduledoc() =~ "mix crap"
      assert Mix.Tasks.Crap.moduledoc() =~ "mix test --cover --export-coverage default"
      assert Mix.Tasks.Crap.moduledoc() =~ "--coverdata"
      assert Mix.Tasks.Crap.moduledoc() =~ "lib/**/*.ex"
      assert Mix.Tasks.Crap.moduledoc() =~ "report-only"
    end
  end

  describe "run/1" do
    test "prints usage for help" do
      output = capture_io(fn -> Mix.Tasks.Crap.run(["--help"]) end)

      assert output =~ "Usage: mix crap"
      assert output =~ "mix test --cover --export-coverage default"
      assert output =~ "mix crap --coverdata path/to/file.coverdata"
      assert output =~ "--coverdata"
      assert output =~ "lib/**/*.ex"
    end

    test "raises for unknown options" do
      assert_raise Mix.Error, ~r/Unknown option: --wat/, fn ->
        Mix.Tasks.Crap.run(["--wat"])
      end
    end

    test "raises for unreadable explicit coverdata" do
      in_tmp("crap-unreadable-coverdata", fn ->
        File.mkdir_p!("lib")
        File.write!("lib/example.ex", "defmodule Example do\n  def ok, do: :ok\nend\n")

        assert_raise Mix.Error, ~r/Coverage data is unreadable: .*missing.coverdata/, fn ->
          Mix.Tasks.Crap.run(["--coverdata", "missing.coverdata"])
        end
      end)
    end

    test "prints guidance when no root lib files exist" do
      in_tmp("crap-empty", fn ->
        output = capture_io(fn -> Mix.Tasks.Crap.run([]) end)

        assert output =~ "No root lib/**/*.ex files found"
      end)
    end

    test "prints coverage guidance when source exists but no coverage data is available" do
      in_tmp("crap-no-coverage", fn ->
        File.mkdir_p!("lib")
        File.write!("lib/example.ex", "defmodule Example do\n  def ok, do: :ok\nend\n")

        output = capture_io(fn -> Mix.Tasks.Crap.run([]) end)

        assert output =~ "No coverage data found"
        assert output =~ "cover/default.coverdata"
        assert output =~ "mix test --cover --export-coverage default"
        assert output =~ "mix crap"
        assert output =~ "mix test --cover prints a coverage report"
        assert output =~ "does not leave importable coverage data"
        assert output =~ "mix crap --coverdata path/to/file.coverdata"
      end)
    end

    test "prints a CRAP report from explicit coverdata" do
      coverdata_path =
        Path.join(System.tmp_dir!(), "crap-task-#{System.unique_integer([:positive])}.coverdata")

      cover_active? = cover_active?()

      unless cover_active?, do: assert({:ok, Crap} = :cover.compile_beam(Crap))

      assert {:ok, 1.0} = Crap.score(1, 100)
      assert :ok = :cover.export(String.to_charlist(coverdata_path))

      unless cover_active? do
        :cover.stop()

        output = capture_io(fn -> Mix.Tasks.Crap.run(["--coverdata", coverdata_path]) end)

        refute output =~ "Analysis includes data"
        assert output =~ "File | Module | Function | Complexity | Coverage | CRAP | Status"
        assert output =~ "Crap | score/2"
        assert output =~ "scored"
      end

      unless cover_active?, do: :cover.stop()
      File.rm(coverdata_path)
    end
  end

  defp cover_active? do
    case :cover.start() do
      {:ok, _pid} ->
        false

      {:error, {:already_started, _pid}} ->
        true
    end
  end

  defp in_tmp(name, fun) do
    root = Path.join(System.tmp_dir!(), "#{name}-#{System.unique_integer([:positive])}")
    File.rm_rf!(root)
    File.mkdir_p!(root)

    previous = File.cwd!()

    try do
      File.cd!(root, fun)
    after
      File.cd!(previous)
      File.rm_rf!(root)
    end
  end
end
