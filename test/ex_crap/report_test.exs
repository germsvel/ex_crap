defmodule ExCrap.ReportTest do
  use ExUnit.Case, async: true

  describe "rows/2" do
    test "scores functions with matching coverage" do
      functions = [
        %{
          file: "/project/lib/example.ex",
          module: Example,
          function: :visible?,
          arity: 1,
          complexity: 4
        }
      ]

      coverage = %{{Example, :visible?, 1} => 75}

      assert ExCrap.Report.rows(functions, coverage) == [
               %{
                 file: "/project/lib/example.ex",
                 module: Example,
                 function: :visible?,
                 arity: 1,
                 complexity: 4,
                 coverage_percent: 75,
                 score: 4.25,
                 status: :scored
               }
             ]
    end

    test "scores functions with missing coverage as zero percent" do
      functions = [
        %{
          file: "/project/lib/example.ex",
          module: Example,
          function: :hidden,
          arity: 0,
          complexity: 1
        }
      ]

      assert ExCrap.Report.rows(functions, %{}) == [
               %{
                 file: "/project/lib/example.ex",
                 module: Example,
                 function: :hidden,
                 arity: 0,
                 complexity: 1,
                 coverage_percent: 0,
                 score: 2.0,
                 status: :scored
               }
             ]
    end

    test "surfaces invalid coverage without crashing unrelated rows" do
      functions = [
        %{
          file: "/project/lib/example.ex",
          module: Example,
          function: :bad,
          arity: 0,
          complexity: 1
        },
        %{
          file: "/project/lib/example.ex",
          module: Example,
          function: :good,
          arity: 0,
          complexity: 1
        }
      ]

      coverage = %{{Example, :bad, 0} => 101, {Example, :good, 0} => 100}

      assert [bad, good] = ExCrap.Report.rows(functions, coverage)
      assert bad.status == {:error, :invalid_coverage}
      assert bad.score == nil
      assert good.status == :scored
      assert good.score == 1.0
    end

    test "normalizes files relative to the provided root" do
      functions = [
        %{
          file: "/project/lib/example.ex",
          module: Example,
          function: :visible?,
          arity: 1,
          complexity: 4
        }
      ]

      coverage = %{{Example, :visible?, 1} => 75}

      assert [row] = ExCrap.Report.rows(functions, coverage, "/project")
      assert row.file == "lib/example.ex"
    end
  end

  describe "render/1" do
    test "renders passing rows as a green checkmark progress line and a compact summary" do
      rows = [
        %{
          file: "/project/lib/a.ex",
          module: Example,
          function: :small,
          arity: 0,
          complexity: 1,
          coverage_percent: 100,
          score: 1.0,
          status: :scored
        },
        %{
          file: "/project/lib/b.ex",
          module: Example,
          function: :risky,
          arity: 1,
          complexity: 4,
          coverage_percent: 0,
          score: 20.0,
          status: :scored
        },
        %{
          file: "/project/lib/c.ex",
          module: Example,
          function: :missing,
          arity: 0,
          complexity: 2,
          coverage_percent: 0,
          score: 6.0,
          status: :scored
        }
      ]

      output = ExCrap.Report.render(rows, verbose: false)

      refute output =~ "File | Module | Function | Complexity | Coverage | CRAP | Status"
      assert output =~ "\e[32m✓✓✓\e[0m\nSummary:"
      refute output =~ "/project/lib/a.ex"
      refute output =~ "/project/lib/b.ex"
      refute output =~ "/project/lib/c.ex"

      assert output =~
               "Summary: files=3 functions=3 scored=3 worst_score=20.00"

      progress_line = output |> String.split("\n", trim: true) |> hd()
      assert progress_line == "\e[32m✓✓✓\e[0m"
      refute progress_line =~ "score="
    end

    test "renders a full colored table when verbose" do
      rows = [
        %{
          file: "/project/lib/a.ex",
          module: Example,
          function: :small,
          arity: 0,
          complexity: 1,
          coverage_percent: 100,
          score: 1.0,
          status: :scored
        },
        %{
          file: "/project/lib/b.ex",
          module: Example,
          function: :risky,
          arity: 1,
          complexity: 4,
          coverage_percent: 0,
          score: 20.0,
          status: :scored
        }
      ]

      output = ExCrap.Report.render(rows)

      assert output =~ "File | Module | Function | Complexity | Coverage | CRAP | Status"
      assert output =~ "\e[32m/project/lib/b.ex | Example | risky/1 | 4 | 0.00% | 20.00 | scored"
      assert output =~ "Summary: files=2 functions=2 scored=2 worst_score=20.00"
      assert output == ExCrap.Report.render(rows, verbose: true)
    end

    test "renders failures as red x markers in compact output" do
      rows = [
        %{
          file: "/project/lib/risky.ex",
          module: Example,
          function: :risky,
          arity: 0,
          complexity: 10,
          coverage_percent: 0,
          score: 110.0,
          status: :scored
        },
        %{
          file: "/project/lib/safe.ex",
          module: Example,
          function: :safe,
          arity: 0,
          complexity: 1,
          coverage_percent: 100,
          score: 1.0,
          status: :scored
        },
        %{
          file: "/project/lib/error.ex",
          module: Example,
          function: :bad,
          arity: 0,
          complexity: 1,
          coverage_percent: nil,
          score: nil,
          status: {:error, :invalid_coverage}
        }
      ]

      output = ExCrap.Report.render(rows, max_score: 30, verbose: false)
      progress_line = output |> String.split("\n", trim: true) |> hd()

      assert progress_line == "\e[31mx\e[0m\e[32m✓\e[0m\e[31mx\e[0m"
      assert output =~ "Summary: files=3 functions=3 scored=2 worst_score=110.00"
    end

    test "renders failures as red rows when verbose" do
      rows = [
        %{
          file: "/project/lib/risky.ex",
          module: Example,
          function: :risky,
          arity: 0,
          complexity: 10,
          coverage_percent: 0,
          score: 110.0,
          status: :scored
        },
        %{
          file: "/project/lib/safe.ex",
          module: Example,
          function: :safe,
          arity: 0,
          complexity: 1,
          coverage_percent: 100,
          score: 1.0,
          status: :scored
        },
        %{
          file: "/project/lib/error.ex",
          module: Example,
          function: :bad,
          arity: 0,
          complexity: 1,
          coverage_percent: nil,
          score: nil,
          status: {:error, :invalid_coverage}
        }
      ]

      output = ExCrap.Report.render(rows, max_score: 30, verbose: true)

      assert output =~
               "\e[31m/project/lib/risky.ex | Example | risky/0 | 10 | 0.00% | 110.00 | scored\e[0m"

      assert output =~
               "\e[32m/project/lib/safe.ex | Example | safe/0 | 1 | 100.00% | 1.00 | scored\e[0m"

      assert output =~
               "\e[31m/project/lib/error.ex | Example | bad/0 | 1 | missing | - | error: invalid_coverage\e[0m"
    end

    test "renders high scores without raising" do
      rows = [
        %{
          file: "/project/lib/risky.ex",
          module: Example,
          function: :risky,
          arity: 0,
          complexity: 10,
          coverage_percent: 0,
          score: 110.0,
          status: :scored
        }
      ]

      assert ExCrap.Report.render(rows, verbose: true) =~ "110.00"
    end
  end

  describe "failures/2" do
    test "groups high scores and score errors" do
      rows = [
        %{
          file: "lib/risky.ex",
          module: Example,
          function: :risky,
          arity: 0,
          complexity: 10,
          coverage_percent: 0,
          score: 110.0,
          status: :scored
        },
        %{
          file: "lib/error.ex",
          module: Example,
          function: :bad,
          arity: 0,
          complexity: 1,
          coverage_percent: nil,
          score: nil,
          status: {:error, :invalid_coverage}
        },
        %{
          file: "lib/safe.ex",
          module: Example,
          function: :safe,
          arity: 0,
          complexity: 1,
          coverage_percent: 100,
          score: 1.0,
          status: :scored
        }
      ]

      assert %{
               high_scores: [high_score],
               score_errors: [score_error]
             } = ExCrap.Report.failures(rows, 30)

      assert high_score.function == :risky
      assert score_error.function == :bad
    end

    test "does not flag scores equal to the threshold" do
      rows = [
        %{
          file: "lib/exact.ex",
          module: Example,
          function: :exact,
          arity: 0,
          complexity: 1,
          coverage_percent: 100,
          score: 30.0,
          status: :scored
        }
      ]

      assert ExCrap.Report.failures(rows, 30) == %{
               high_scores: [],
               score_errors: []
             }
    end
  end
end
