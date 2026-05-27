defmodule Crap.ReportTest do
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

      assert Crap.Report.rows(functions, coverage) == [
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

    test "keeps functions with missing coverage visible" do
      functions = [
        %{
          file: "/project/lib/example.ex",
          module: Example,
          function: :hidden,
          arity: 0,
          complexity: 1
        }
      ]

      assert Crap.Report.rows(functions, %{}) == [
               %{
                 file: "/project/lib/example.ex",
                 module: Example,
                 function: :hidden,
                 arity: 0,
                 complexity: 1,
                 coverage_percent: nil,
                 score: nil,
                 status: {:missing_coverage, {Example, :hidden, 0}}
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

      assert [bad, good] = Crap.Report.rows(functions, coverage)
      assert bad.status == {:error, :invalid_coverage}
      assert bad.score == nil
      assert good.status == :scored
      assert good.score == 1.0
    end
  end

  describe "render/1" do
    test "renders sorted rows and a compact summary" do
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
          coverage_percent: nil,
          score: nil,
          status: {:missing_coverage, {Example, :missing, 0}}
        }
      ]

      output = Crap.Report.render(rows)

      assert output =~ "File | Module | Function | Complexity | Coverage | CRAP | Status"
      assert output =~ "/project/lib/b.ex | Example | risky/1 | 4 | 0.00% | 20.00 | scored"

      assert output =~
               "/project/lib/c.ex | Example | missing/0 | 2 | missing | - | missing coverage"

      assert output =~
               "Summary: files=3 functions=3 scored=2 missing_coverage=1 worst_score=20.00"

      assert :binary.match(output, "risky/1") < :binary.match(output, "small/0")
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

      assert Crap.Report.render(rows) =~ "110.00"
    end
  end
end
