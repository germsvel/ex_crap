defmodule CrapTest do
  use ExUnit.Case, async: true

  describe "score/2" do
    test "returns complexity unchanged for 100 percent coverage" do
      assert Crap.score(7, 100) == {:ok, 7.0}
    end

    test "returns complexity squared plus complexity for 0 percent coverage" do
      assert Crap.score(4, 0) == {:ok, 20.0}
    end

    test "preserves fractional scores for intermediate coverage" do
      assert Crap.score(4, 75) == {:ok, 4.25}
    end

    test "rejects invalid complexity" do
      assert Crap.score(-1, 50) == {:error, :invalid_complexity}
      assert Crap.score(:high, 50) == {:error, :invalid_complexity}
    end

    test "rejects invalid coverage" do
      assert Crap.score(4, -1) == {:error, :invalid_coverage}
      assert Crap.score(4, 101) == {:error, :invalid_coverage}
      assert Crap.score(4, :covered) == {:error, :invalid_coverage}
    end
  end

  describe "analyze_string/2" do
    test "returns CRAP scores for functions with matching explicit coverage" do
      source = """
      defmodule Example do
        def visible?(user) do
          if user.active, do: true, else: false
        end
      end
      """

      coverage = %{{Example, :visible?, 1} => 50}

      assert {:ok,
              [
                %{
                  module: Example,
                  function: :visible?,
                  arity: 1,
                  complexity: 2,
                  coverage_percent: 50,
                  score: 2.5,
                  status: :scored
                }
              ]} = Crap.analyze_string(source, coverage)
    end

    test "marks functions with missing coverage without discovering coverage automatically" do
      source = """
      defmodule Example do
        def uncovered, do: :ok
      end
      """

      assert {:ok,
              [
                %{
                  module: Example,
                  function: :uncovered,
                  arity: 0,
                  status: {:missing_coverage, {Example, :uncovered, 0}}
                }
              ]} = Crap.analyze_string(source, %{})
    end
  end

  describe "analyze_file/2" do
    test "returns CRAP scores for realistic source file functions with explicit coverage" do
      path = Path.expand("../fixtures/realistic_sample.ex", __DIR__)

      coverage = %{
        {Realistic.Sample, :normalize, 1} => 100,
        {Realistic.Sample, :classify, 1} => 75,
        {Realistic.Sample, :visible?, 1} => 50,
        {Realistic.Sample, :fallback, 1} => 0
      }

      assert {:ok, results} = Crap.analyze_file(path, coverage)

      assert Enum.find(results, &(&1.function == :normalize)).score == 1.0
      assert Enum.find(results, &(&1.function == :classify)).score == 4.25
      assert Enum.find(results, &(&1.function == :visible?)).score == 4.125
      assert Enum.find(results, &(&1.function == :fallback)).score == 20.0
    end
  end
end
