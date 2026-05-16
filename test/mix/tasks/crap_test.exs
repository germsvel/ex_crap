defmodule Mix.Tasks.CrapTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  describe "task metadata" do
    test "exposes mix task docs" do
      assert Mix.Tasks.Crap.shortdoc() == "Print CRAP scores for project source"

      assert Mix.Tasks.Crap.moduledoc() =~ "mix crap"
      assert Mix.Tasks.Crap.moduledoc() =~ "mix test --cover --export-coverage default"
      assert Mix.Tasks.Crap.moduledoc() =~ "--coverdata"
      assert Mix.Tasks.Crap.moduledoc() =~ "--max-score"
      assert Mix.Tasks.Crap.moduledoc() =~ "default: 30"
      assert Mix.Tasks.Crap.moduledoc() =~ "lib/**/*.ex"
      assert Mix.Tasks.Crap.moduledoc() =~ "missing coverage"
      assert Mix.Tasks.Crap.moduledoc() =~ "score calculation error"
      refute Mix.Tasks.Crap.moduledoc() =~ "report-only"
    end
  end

  describe "run/1" do
    test "prints usage for help" do
      output = capture_io(fn -> Mix.Tasks.Crap.run(["--help"]) end)

      assert output =~ "Usage: mix crap"
      assert output =~ "mix test --cover --export-coverage default"
      assert output =~ "mix crap --coverdata path/to/file.coverdata"
      assert output =~ "mix crap --max-score 30"
      assert output =~ "--coverdata"
      assert output =~ "--max-score"
      assert output =~ "lib/**/*.ex"
    end

    test "raises for invalid max score" do
      for value <- ["nope", "10wat", "0", "-1"] do
        assert_raise Mix.Error,
                     "Invalid --max-score: #{value}. Expected a positive number.",
                     fn ->
                       Mix.Tasks.Crap.run(["--max-score", value])
                     end
      end
    end

    test "raises for unknown options" do
      assert_raise Mix.Error, ~r/Unknown option: --wat/, fn ->
        Mix.Tasks.Crap.run(["--wat"])
      end
    end

    test "raises for unexpected positional arguments" do
      assert_raise Mix.Error, "Unexpected argument: foo", fn ->
        Mix.Tasks.Crap.run(["foo"])
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

    test "prints coverage guidance and raises when source exists but no coverage data is available" do
      in_tmp("crap-no-coverage", fn ->
        File.mkdir_p!("lib")
        File.write!("lib/example.ex", "defmodule Example do\n  def ok, do: :ok\nend\n")

        output =
          capture_io(fn ->
            assert_raise Mix.Error, ~r/Coverage data is missing/, fn ->
              Mix.Tasks.Crap.run([])
            end
          end)

        assert output =~ "No coverage data found"
        assert output =~ "cover/default.coverdata"
        assert output =~ "mix test --cover --export-coverage default"
        assert output =~ "mix crap"
        assert output =~ "mix test --cover prints a coverage report"
        assert output =~ "does not leave importable coverage data"
        assert output =~ "mix crap --coverdata path/to/file.coverdata"
      end)
    end

    test "prints a CRAP report from explicit coverdata when rows pass the threshold" do
      with_coverdata(fn coverdata_path ->
        in_tmp("crap-explicit-coverdata", fn ->
          File.mkdir_p!("lib")

          File.write!(
            "lib/example.ex",
            "defmodule Crap do\n  def score(complexity, coverage), do: {complexity, coverage}\nend\n"
          )

          output = capture_io(fn -> Mix.Tasks.Crap.run(["--coverdata", coverdata_path]) end)

          refute output =~ "Analysis includes data"
          assert output =~ "File | Module | Function | Complexity | Coverage | CRAP | Status"
          assert output =~ "lib/example.ex | Crap | score/2"
          assert output =~ "scored"
        end)
      end)
    end

    test "raises with high score summary after printing the report" do
      with_coverdata(fn coverdata_path ->
        in_tmp("crap-high-score", fn ->
          File.mkdir_p!("lib")

          File.write!(
            "lib/example.ex",
            "defmodule Crap do\n  def score(complexity, coverage), do: {complexity, coverage}\nend\n"
          )

          output =
            capture_io(fn ->
              assert_raise Mix.Error,
                           ~r/CRAP threshold failed: max_score=0\.01.*High scores: 1\n  lib\/example\.ex Crap\.score\/2 score=\d+\.\d{2}/s,
                           fn ->
                             Mix.Tasks.Crap.run([
                               "--coverdata",
                               coverdata_path,
                               "--max-score",
                               "0.01"
                             ])
                           end
            end)

          assert output =~ "File | Module | Function | Complexity | Coverage | CRAP | Status"
          assert output =~ "lib/example.ex | Crap | score/2"
        end)
      end)
    end

    test "raises with missing coverage summary even without high scores" do
      with_coverdata(fn coverdata_path ->
        in_tmp("crap-missing-coverage", fn ->
          File.mkdir_p!("lib")
          File.write!("lib/example.ex", "defmodule Example do\n  def ok, do: :ok\nend\n")

          capture_io(fn ->
            assert_raise Mix.Error,
                         ~r/Missing coverage: 1\n  lib\/example\.ex Example\.ok\/0 status=missing coverage/,
                         fn ->
                           Mix.Tasks.Crap.run([
                             "--coverdata",
                             coverdata_path,
                             "--max-score",
                             "999"
                           ])
                         end
          end)
        end)
      end)
    end
  end

  defp with_coverdata(fun) do
    coverdata_path =
      Path.join(System.tmp_dir!(), "crap-task-#{System.unique_integer([:positive])}.coverdata")

    cover_active? = cover_active?()

    unless cover_active?, do: assert({:ok, Crap} = :cover.compile_beam(Crap))

    assert {:ok, 1.0} = Crap.score(1, 100)
    assert :ok = :cover.export(String.to_charlist(coverdata_path))

    unless cover_active?, do: :cover.stop()

    try do
      fun.(coverdata_path)
    after
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
