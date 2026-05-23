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
      assert Mix.Tasks.Crap.moduledoc() =~ "--verbose"
      assert Mix.Tasks.Crap.moduledoc() =~ "default: 30"
      assert Mix.Tasks.Crap.moduledoc() =~ "lib/**/*.ex"

      assert Mix.Tasks.Crap.moduledoc() =~
               "skips valid files with no analyzable function or macro bodies"

      assert Mix.Tasks.Crap.moduledoc() =~ ~r/Missing function\s+coverage is scored as 0%/
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
      assert output =~ "--verbose"
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

    test "prints guidance when source files have no analyzable function bodies" do
      in_tmp("crap-no-analyzable-functions", fn ->
        File.mkdir_p!("lib")

        File.write!("lib/driver.ex", """
        defprotocol Example.Driver do
          def visit(initial_struct, path)
        end
        """)

        output = capture_io(fn -> Mix.Tasks.Crap.run([]) end)

        assert output =~ "No analyzable function bodies found in root lib/**/*.ex files"
        refute output =~ "No coverage data found"
        refute output =~ "invalid_source"
      end)
    end

    test "requires coverage when at least one analyzable function exists" do
      in_tmp("crap-mixed-source-no-coverage", fn ->
        File.mkdir_p!("lib")

        File.write!("lib/a_driver.ex", """
        defprotocol Example.Driver do
          def visit(initial_struct, path)
        end
        """)

        File.write!("lib/b_example.ex", """
        defmodule Example do
          def ok, do: :ok
        end
        """)

        output =
          capture_io(fn ->
            assert_raise Mix.Error, ~r/Coverage data is missing/, fn ->
              Mix.Tasks.Crap.run([])
            end
          end)

        assert output =~ "No coverage data found"
        refute output =~ "No analyzable function bodies found"
      end)
    end

    test "raises a source analysis error for invalid source" do
      in_tmp("crap-invalid-source", fn ->
        File.mkdir_p!("lib")
        File.write!("lib/bad.ex", "defmodule")

        assert_raise Mix.Error,
                     ~r/Unable to analyze source file lib\/bad\.ex: :invalid_source/,
                     fn ->
                       Mix.Tasks.Crap.run([])
                     end
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

    test "prints concise success output from explicit coverdata when rows pass the threshold" do
      with_coverdata(fn coverdata_path ->
        in_tmp("crap-explicit-coverdata", fn ->
          File.mkdir_p!("lib")

          File.write!(
            "lib/example.ex",
            "defmodule ExCrap do\n  def score(complexity, coverage), do: {complexity, coverage}\nend\n"
          )

          output = capture_io(fn -> Mix.Tasks.Crap.run(["--coverdata", coverdata_path]) end)

          refute output =~ "Analysis includes data"
          assert output =~ "\e[32m✓\e[0m\nSummary:"
          assert output =~ "Summary:"
          refute output =~ "File | Module | Function | Complexity | Coverage | CRAP | Status"
          refute output =~ "lib/example.ex | ExCrap | score/2"
          refute output =~ "lib/example.ex | ExCrap | score/2 | 1 | 100.00% | 1.00 | scored"

          progress_line = output |> String.split("\n", trim: true) |> hd()
          assert progress_line == "\e[32m✓\e[0m"
          refute progress_line =~ "score="
        end)
      end)
    end

    test "prints a full colored CRAP report from explicit coverdata when verbose" do
      with_coverdata(fn coverdata_path ->
        in_tmp("crap-explicit-coverdata-verbose", fn ->
          File.mkdir_p!("lib")

          File.write!(
            "lib/example.ex",
            "defmodule ExCrap do\n  def score(complexity, coverage), do: {complexity, coverage}\nend\n"
          )

          output =
            capture_io(fn -> Mix.Tasks.Crap.run(["--coverdata", coverdata_path, "--verbose"]) end)

          assert output =~ "File | Module | Function | Complexity | Coverage | CRAP | Status"
          assert output =~ "lib/example.ex | ExCrap | score/2"
          assert output =~ "Summary:"
          assert output =~ "\e[32mlib/example.ex | ExCrap | score/2"
          assert output =~ "scored"
        end)
      end)
    end

    test "raises with high score summary after printing the summary" do
      with_coverdata(fn coverdata_path ->
        in_tmp("crap-high-score", fn ->
          File.mkdir_p!("lib")

          File.write!(
            "lib/example.ex",
            "defmodule ExCrap do\n  def score(complexity, coverage), do: {complexity, coverage}\nend\n"
          )

          output =
            capture_io(fn ->
              assert_raise Mix.Error,
                           ~r/CRAP threshold failed: max_score=0\.01.*High scores: 1\n  lib\/example\.ex ExCrap\.score\/2 score=\d+\.\d{2}/s,
                           fn ->
                             Mix.Tasks.Crap.run([
                               "--coverdata",
                               coverdata_path,
                               "--max-score",
                               "0.01"
                             ])
                           end
            end)

          assert output =~ "Summary:"
          refute output =~ "File | Module | Function | Complexity | Coverage | CRAP | Status"
          refute output =~ "lib/example.ex | ExCrap | score/2"
          refute output =~ "lib/example.ex | ExCrap | score/2 | 1 | 100.00% | 1.00 | scored"
        end)
      end)
    end

    test "prints a full colored CRAP report before raising when verbose" do
      with_coverdata(fn coverdata_path ->
        in_tmp("crap-high-score-verbose", fn ->
          File.mkdir_p!("lib")

          File.write!(
            "lib/example.ex",
            "defmodule ExCrap do\n  def score(complexity, coverage), do: {complexity, coverage}\nend\n"
          )

          output =
            capture_io(fn ->
              assert_raise Mix.Error,
                           ~r/CRAP threshold failed: max_score=0\.01.*High scores: 1\n  lib\/example\.ex ExCrap\.score\/2 score=\d+\.\d{2}/s,
                           fn ->
                             Mix.Tasks.Crap.run([
                               "--coverdata",
                               coverdata_path,
                               "--max-score",
                               "0.01",
                               "--verbose"
                             ])
                           end
            end)

          assert output =~ "File | Module | Function | Complexity | Coverage | CRAP | Status"
          assert output =~ "lib/example.ex | ExCrap | score/2"
          assert output =~ "Summary:"
        end)
      end)
    end

    test "raises with every high score in the threshold summary" do
      with_coverdata(fn coverdata_path ->
        in_tmp("crap-all-high-scores", fn ->
          File.mkdir_p!("lib")

          File.write!(
            "lib/example.ex",
            """
            defmodule Example do
              def risky1(a, b, c, d), do: risky(a, b, c, d)
              def risky2(a, b, c, d), do: risky(a, b, c, d)
              def risky3(a, b, c, d), do: risky(a, b, c, d)
              def risky4(a, b, c, d), do: risky(a, b, c, d)
              def risky5(a, b, c, d), do: risky(a, b, c, d)
              def risky6(a, b, c, d), do: risky(a, b, c, d)

              defp risky(a, b, c, d) do
                cond do
                  a -> :a
                  b -> :b
                  c -> :c
                  d -> :d
                  true -> :fallback
                end
              end
            end
            """
          )

          test_pid = self()

          capture_io(fn ->
            error =
              assert_raise Mix.Error, fn ->
                Mix.Tasks.Crap.run([
                  "--coverdata",
                  coverdata_path,
                  "--max-score",
                  "0.01"
                ])
              end

            send(test_pid, {:error, error})
          end)

          assert_receive {:error, error}

          message = Exception.message(error)

          assert message =~ "High scores: 7"

          for name <- ~w(risky risky1 risky2 risky3 risky4 risky5 risky6) do
            assert message =~ "lib/example.ex Example.#{name}/4 score="
          end

          refute message =~ "... and"
        end)
      end)
    end

    test "scores missing function coverage as zero and passes when score is within threshold" do
      with_coverdata(fn coverdata_path ->
        in_tmp("crap-missing-coverage-under-threshold", fn ->
          File.mkdir_p!("lib")
          File.write!("lib/example.ex", "defmodule Example do\n  def ok, do: :ok\nend\n")

          output =
            capture_io(fn ->
              Mix.Tasks.Crap.run([
                "--coverdata",
                coverdata_path,
                "--max-score",
                "30"
              ])
            end)

          assert output =~ "\e[32m✓\e[0m\nSummary:"
          assert output =~ "Summary:"
          refute output =~ "lib/example.ex | Example | ok/0 | 1 | 0.00% | 2.00 | scored"
          refute output =~ "Missing coverage"

          progress_line = output |> String.split("\n", trim: true) |> hd()
          assert progress_line == "\e[32m✓\e[0m"
          refute progress_line =~ "score="
        end)
      end)
    end

    test "fails when missing function coverage produces a score above the threshold" do
      with_coverdata(fn coverdata_path ->
        in_tmp("crap-missing-coverage-over-threshold", fn ->
          File.mkdir_p!("lib")

          File.write!(
            "lib/example.ex",
            """
            defmodule Example do
              def risky(a, b, c, d) do
                cond do
                  a -> :a
                  b -> :b
                  c -> :c
                  d -> :d
                  true -> :fallback
                end
              end
            end
            """
          )

          output =
            capture_io(fn ->
              assert_raise Mix.Error,
                           ~r/CRAP threshold failed: max_score=30\.00.*High scores: 1\n  lib\/example\.ex Example\.risky\/4 score=42\.00/s,
                           fn ->
                             Mix.Tasks.Crap.run([
                               "--coverdata",
                               coverdata_path,
                               "--max-score",
                               "30"
                             ])
                           end
            end)

          assert output =~ "Summary:"
          refute output =~ "lib/example.ex | Example | risky/4 | 6 | 0.00% | 42.00 | scored"
          refute output =~ "Missing coverage"
        end)
      end)
    end
  end

  defp with_coverdata(fun) do
    coverdata_path =
      Path.join(System.tmp_dir!(), "crap-task-#{System.unique_integer([:positive])}.coverdata")

    cover_active? = cover_active?()

    unless cover_active?, do: assert({:ok, ExCrap} = :cover.compile_beam(ExCrap))

    assert {:ok, 1.0} = ExCrap.score(1, 100)
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
