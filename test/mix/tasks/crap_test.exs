defmodule Mix.Tasks.CrapTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  setup context do
    if tmp_dir = context[:tmp_dir] do
      Process.put(:tmp_dir, tmp_dir)
    end

    :ok
  end

  describe "task metadata" do
    test "exposes mix task docs" do
      assert Mix.Tasks.Crap.shortdoc() == "Print CRAP scores for project source"

      assert Mix.Tasks.Crap.moduledoc() =~ "mix crap"
      assert Mix.Tasks.Crap.moduledoc() =~ "mix test --cover --export-coverage default"
      assert Mix.Tasks.Crap.moduledoc() =~ "--coverdata"
      assert Mix.Tasks.Crap.moduledoc() =~ "--max-score"
      assert Mix.Tasks.Crap.moduledoc() =~ "--path"
      assert Mix.Tasks.Crap.moduledoc() =~ "--verbose"
      assert Mix.Tasks.Crap.moduledoc() =~ "default: 30"
      assert Mix.Tasks.Crap.moduledoc() =~ "default: lib"
      assert Mix.Tasks.Crap.moduledoc() =~ "lib/**/*.ex"
      assert Mix.Tasks.Crap.moduledoc() =~ "mix crap --path path/to/source"

      assert Mix.Tasks.Crap.moduledoc() =~
               "It skips\nvalid files with no analyzable function or macro bodies"

      assert Mix.Tasks.Crap.moduledoc() =~ ~r/Missing function\s+coverage is scored as 0%/
      assert Mix.Tasks.Crap.moduledoc() =~ "score calculation error"
      refute Mix.Tasks.Crap.moduledoc() =~ "report-only"
    end
  end

  describe "run/1" do
    @describetag :tmp_dir

    test "prints usage for help" do
      output = capture_io(fn -> Mix.Tasks.Crap.run(["--help"]) end)

      assert output =~ "Usage: mix crap"
      assert output =~ "mix test --cover --export-coverage default"
      assert output =~ "mix crap --coverdata path/to/file.coverdata"
      assert output =~ "mix crap --max-score 30"
      assert output =~ "mix crap --path path/to/source"
      assert output =~ "--coverdata"
      assert output =~ "--max-score"
      assert output =~ "--path"
      assert output =~ "--verbose"
      assert output =~ "default: lib"
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
      in_tmp("crap-unreadable-coverdata", fn root ->
        write_source(root, "lib/example.ex", "defmodule Example do\n  def ok, do: :ok\nend\n")

        assert_raise Mix.Error, ~r/Coverage data is unreadable: .*missing.coverdata/, fn ->
          run_with_source(root, ["--coverdata", "missing.coverdata"])
        end
      end)
    end

    test "prints guidance when no root lib files exist" do
      in_tmp("crap-empty", fn root ->
        output = capture_io(fn -> run_with_source(root) end)

        assert output =~ "No root #{displayed_source_path(root)}/**/*.ex files found"
      end)
    end

    test "prints guidance when custom path has no source files" do
      in_tmp("crap-custom-path-empty", fn root ->
        output =
          capture_io(fn -> Mix.Tasks.Crap.run(["--path", source_path(root, "fixtures")]) end)

        assert output =~ "No root #{displayed_source_path(root, "fixtures")}/**/*.ex files found"
      end)
    end

    test "prints guidance when source files have no analyzable function bodies" do
      in_tmp("crap-no-analyzable-functions", fn root ->
        write_source(root, "lib/driver.ex", """
        defprotocol Example.Driver do
          def visit(initial_struct, path)
        end
        """)

        output = capture_io(fn -> run_with_source(root) end)

        assert output =~
                 "No analyzable function bodies found in root #{displayed_source_path(root)}/**/*.ex files"

        refute output =~ "No coverage data found"
        refute output =~ "invalid_source"
      end)
    end

    test "prints guidance when custom path has no analyzable function bodies" do
      in_tmp("crap-custom-path-no-analyzable-functions", fn root ->
        write_source(root, "fixtures/driver.ex", """
        defprotocol Example.Driver do
          def visit(initial_struct, path)
        end
        """)

        output =
          capture_io(fn -> Mix.Tasks.Crap.run(["--path", source_path(root, "fixtures")]) end)

        assert output =~
                 "No analyzable function bodies found in root #{displayed_source_path(root, "fixtures")}/**/*.ex files"

        refute output =~ "No coverage data found"
      end)
    end

    test "requires readable coverage when at least one analyzable function exists" do
      in_tmp("crap-mixed-source-no-coverage", fn root ->
        write_source(root, "lib/a_driver.ex", """
        defprotocol Example.Driver do
          def visit(initial_struct, path)
        end
        """)

        write_source(root, "lib/b_example.ex", """
        defmodule Example do
          def ok, do: :ok
        end
        """)

        output =
          capture_io(fn ->
            assert_raise Mix.Error, ~r/Coverage data is unreadable/, fn ->
              run_with_source(root, ["--coverdata", Path.join(root, "missing.coverdata")])
            end
          end)

        assert output == ""
        refute output =~ "No analyzable function bodies found"
      end)
    end

    test "raises a source analysis error for invalid source" do
      in_tmp("crap-invalid-source", fn root ->
        write_source(root, "lib/bad.ex", "defmodule")

        assert_raise Mix.Error,
                     ~r/Unable to analyze source file .*lib\/bad\.ex: :invalid_source/,
                     fn ->
                       run_with_source(root)
                     end
      end)
    end

    test "raises when source exists but explicit coverage data is unavailable" do
      in_tmp("crap-no-coverage", fn root ->
        write_source(root, "lib/example.ex", "defmodule Example do\n  def ok, do: :ok\nend\n")

        output =
          capture_io(fn ->
            assert_raise Mix.Error, ~r/Coverage data is unreadable/, fn ->
              run_with_source(root, ["--coverdata", Path.join(root, "missing.coverdata")])
            end
          end)

        assert output == ""
      end)
    end

    test "prints concise success output from explicit coverdata when rows pass the threshold" do
      with_coverdata(fn coverdata_path ->
        in_tmp("crap-explicit-coverdata", fn root ->
          write_source(
            root,
            "lib/example.ex",
            "defmodule ExCrap do\n  def score(complexity, coverage), do: {complexity, coverage}\nend\n"
          )

          output = capture_io(fn -> run_with_source(root, ["--coverdata", coverdata_path]) end)

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
        in_tmp("crap-explicit-coverdata-verbose", fn root ->
          write_source(
            root,
            "lib/example.ex",
            "defmodule ExCrap do\n  def score(complexity, coverage), do: {complexity, coverage}\nend\n"
          )

          output =
            capture_io(fn ->
              run_with_source(root, ["--coverdata", coverdata_path, "--verbose"])
            end)

          assert output =~ "File | Module | Function | Complexity | Coverage | CRAP | Status"
          assert output =~ "#{displayed_source_path(root)}/example.ex | ExCrap | score/2"
          assert output =~ "Summary:"
          assert output =~ "\e[32m#{displayed_source_path(root)}/example.ex | ExCrap | score/2"
          assert output =~ "scored"
        end)
      end)
    end

    test "prints success output from explicit coverdata and custom path" do
      with_coverdata(fn coverdata_path ->
        in_tmp("crap-custom-path-explicit-coverdata", fn root ->
          write_source(
            root,
            "fixtures/example.ex",
            "defmodule ExCrap do\n  def score(complexity, coverage), do: {complexity, coverage}\nend\n"
          )

          write_source(root, "lib/ignored.ex", "defmodule Ignored do\n  def ok, do: :ok\nend\n")

          output =
            capture_io(fn ->
              Mix.Tasks.Crap.run([
                "--coverdata",
                coverdata_path,
                "--path",
                source_path(root, "fixtures"),
                "--verbose"
              ])
            end)

          assert output =~
                   "#{displayed_source_path(root, "fixtures")}/example.ex | ExCrap | score/2"

          refute output =~ "ignored.ex"
          assert output =~ "Summary:"
        end)
      end)
    end

    test "raises with high score summary after printing the summary" do
      with_coverdata(fn coverdata_path ->
        in_tmp("crap-high-score", fn root ->
          write_source(
            root,
            "lib/example.ex",
            "defmodule ExCrap do\n  def score(complexity, coverage), do: {complexity, coverage}\nend\n"
          )

          output =
            capture_io(fn ->
              error =
                assert_raise Mix.Error, fn ->
                  run_with_source(root, ["--coverdata", coverdata_path, "--max-score", "0.01"])
                end

              message = Exception.message(error)

              assert message =~
                       ~r/CRAP threshold failed: max_score=0\.01.*High scores: 1\n  .*lib\/example\.ex ExCrap\.score\/2 score=\d+\.\d{2}/s

              refute message =~ "Score errors"
              refute message =~ "Score calculation errors"
            end)

          assert output =~ "Summary:"
          refute output =~ "File | Module | Function | Complexity | Coverage | CRAP | Status"
          refute output =~ "lib/example.ex | ExCrap | score/2"
          refute output =~ "lib/example.ex | ExCrap | score/2 | 1 | 100.00% | 1.00 | scored"

          progress_line = output |> String.split("\n", trim: true) |> hd()
          assert progress_line == "\e[31mx\e[0m"
        end)
      end)
    end

    test "prints a full colored CRAP report before raising when verbose" do
      with_coverdata(fn coverdata_path ->
        in_tmp("crap-high-score-verbose", fn root ->
          write_source(
            root,
            "lib/example.ex",
            "defmodule ExCrap do\n  def score(complexity, coverage), do: {complexity, coverage}\nend\n"
          )

          output =
            capture_io(fn ->
              error =
                assert_raise Mix.Error, fn ->
                  run_with_source(root, [
                    "--coverdata",
                    coverdata_path,
                    "--max-score",
                    "0.01",
                    "--verbose"
                  ])
                end

              message = Exception.message(error)

              assert message =~
                       ~r/CRAP threshold failed: max_score=0\.01.*High scores: 1\n  .*lib\/example\.ex ExCrap\.score\/2 score=\d+\.\d{2}/s

              refute message =~ "Score errors"
              refute message =~ "Score calculation errors"
            end)

          assert output =~ "File | Module | Function | Complexity | Coverage | CRAP | Status"
          assert output =~ "#{displayed_source_path(root)}/example.ex | ExCrap | score/2"
          assert output =~ "\e[31m#{displayed_source_path(root)}/example.ex | ExCrap | score/2"
          assert output =~ "Summary:"
        end)
      end)
    end

    test "raises with every high score in the threshold summary" do
      with_coverdata(fn coverdata_path ->
        in_tmp("crap-all-high-scores", fn root ->
          write_source(
            root,
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
                run_with_source(root, ["--coverdata", coverdata_path, "--max-score", "0.01"])
              end

            send(test_pid, {:error, error})
          end)

          assert_receive {:error, error}

          message = Exception.message(error)

          assert message =~ "High scores: 7"

          for name <- ~w(risky risky1 risky2 risky3 risky4 risky5 risky6) do
            assert message =~ "#{displayed_source_path(root)}/example.ex Example.#{name}/4 score="
          end

          refute message =~ "... and"
        end)
      end)
    end

    test "scores missing function coverage as zero and passes when score is within threshold" do
      with_coverdata(fn coverdata_path ->
        in_tmp("crap-missing-coverage-under-threshold", fn root ->
          write_source(root, "lib/example.ex", "defmodule Example do\n  def ok, do: :ok\nend\n")

          output =
            capture_io(fn ->
              run_with_source(root, ["--coverdata", coverdata_path, "--max-score", "30"])
            end)

          assert output =~ "\e[32m✓\e[0m\nSummary:"
          assert output =~ "Summary:"

          refute output =~
                   "#{displayed_source_path(root)}/example.ex | Example | ok/0 | 1 | 0.00% | 2.00 | scored"

          refute output =~ "Missing coverage"

          progress_line = output |> String.split("\n", trim: true) |> hd()
          assert progress_line == "\e[32m✓\e[0m"
          refute progress_line =~ "score="
        end)
      end)
    end

    test "fails when missing function coverage produces a score above the threshold" do
      with_coverdata(fn coverdata_path ->
        in_tmp("crap-missing-coverage-over-threshold", fn root ->
          write_source(
            root,
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
                           ~r/CRAP threshold failed: max_score=30\.00.*High scores: 1\n  .*lib\/example\.ex Example\.risky\/4 score=42\.00/s,
                           fn ->
                             run_with_source(root, [
                               "--coverdata",
                               coverdata_path,
                               "--max-score",
                               "30"
                             ])
                           end
            end)

          assert output =~ "Summary:"

          refute output =~
                   "#{displayed_source_path(root)}/example.ex | Example | risky/4 | 6 | 0.00% | 42.00 | scored"

          refute output =~ "Missing coverage"
        end)
      end)
    end
  end

  defp with_coverdata(fun) do
    coverdata_path = Path.join(tmp_dir!(), "crap-task.coverdata")

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
    root = Path.join(tmp_dir!(), name)
    File.mkdir_p!(root)
    fun.(root)
  end

  defp run_with_source(root, args \\ []) do
    Mix.Tasks.Crap.run(["--path", source_path(root) | args])
  end

  defp source_path(root, relative_path \\ "lib") do
    Path.join(root, relative_path)
  end

  defp displayed_source_path(root, relative_path \\ "lib") do
    root
    |> source_path(relative_path)
    |> Path.relative_to(File.cwd!())
  end

  defp write_source(root, relative_path, source) do
    path = Path.join(root, relative_path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, source)
    path
  end

  defp tmp_dir! do
    Process.get(:tmp_dir) || raise "expected @tag :tmp_dir"
  end
end
