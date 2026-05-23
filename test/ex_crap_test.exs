defmodule CrapTest do
  use ExUnit.Case, async: true

  describe "score/2" do
    test "keeps the public score API available" do
      assert ExCrap.score(7, 100) == {:ok, 7.0}
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
              ]} = ExCrap.analyze_string(source, coverage)
    end

    test "scores functions with missing coverage as zero percent" do
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
                  complexity: 1,
                  coverage_percent: 0,
                  score: 2.0,
                  status: :scored
                }
              ]} = ExCrap.analyze_string(source, %{})
    end

    test "returns an empty result for valid source with no analyzable functions" do
      source = """
      defprotocol Example.Protocol do
        def call(value)
      end
      """

      assert ExCrap.analyze_string(source, %{}) == {:ok, []}
    end

    test "accepts default-argument function heads before guarded clauses" do
      source = ~S"""
      defmodule Concat do
        def join(a, b, sep \\ " ")

        def join(a, b, _sep) when b == "" do
          a
        end

        def join(a, b, sep) do
          a <> sep <> b
        end
      end
      """

      assert {:ok, _results} = ExCrap.analyze_string(source, %{})
    end

    test "still returns invalid_source for invalid source" do
      assert ExCrap.analyze_string("defmodule", %{}) == {:error, :invalid_source}
    end

    test "rejects non-map coverage input" do
      assert ExCrap.analyze_string("defmodule Example do\n  def ok, do: :ok\nend\n", []) ==
               {:error, :invalid_coverage_map}
    end

    test "marks functions with invalid coverage values as errors" do
      source = "defmodule Example do\n  def ok, do: :ok\nend\n"

      assert {:ok,
              [
                %{
                  module: Example,
                  function: :ok,
                  arity: 0,
                  status: {:error, :invalid_coverage}
                }
              ]} = ExCrap.analyze_string(source, %{{Example, :ok, 0} => 101})
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

      assert {:ok, results} = ExCrap.analyze_file(path, coverage)

      assert Enum.find(results, &(&1.function == :normalize)).score == 1.0
      assert Enum.find(results, &(&1.function == :classify)).score == 4.25
      assert Enum.find(results, &(&1.function == :visible?)).score == 4.125
      assert Enum.find(results, &(&1.function == :fallback)).score == 20.0
    end

    test "returns an empty result for a valid source file with no analyzable functions" do
      path =
        Path.join(System.tmp_dir!(), "ex-crap-empty-api-#{System.unique_integer([:positive])}.ex")

      File.write!(path, """
      defprotocol Example.Protocol do
        def call(value)
      end
      """)

      try do
        assert ExCrap.analyze_file(path, %{}) == {:ok, []}
      after
        File.rm(path)
      end
    end

    test "rejects non-map coverage input" do
      path = Path.expand("../fixtures/realistic_sample.ex", __DIR__)

      assert ExCrap.analyze_file(path, []) == {:error, :invalid_coverage_map}
    end
  end

  describe "analyze_string/2 integration for new complexity rules" do
    test "scores function with guard boolean operator" do
      source = """
      defmodule Example do
        def valid?(value) when is_binary(value) and byte_size(value) > 0, do: true
      end
      """

      assert {:ok,
              [
                %{
                  module: Example,
                  function: :valid?,
                  arity: 1,
                  complexity: 2,
                  coverage_percent: 0,
                  score: 6.0,
                  status: :scored
                }
              ]} =
               ExCrap.analyze_string(source, %{})
    end

    test "scores aggregated multi-clause function" do
      source = """
      defmodule Example do
        def classify(value) when is_integer(value) and value > 0, do: :positive
        def classify(value) when is_integer(value) and value < 0, do: :negative
        def classify(_value), do: :other
      end
      """

      assert {:ok,
              [
                %{
                  module: Example,
                  function: :classify,
                  arity: 1,
                  complexity: 5,
                  coverage_percent: 0,
                  score: 30.0,
                  status: :scored
                }
              ]} =
               ExCrap.analyze_string(source, %{})
    end

    test "scores function with with/else" do
      source = """
      defmodule Example do
        def load(params) do
          with {:ok, id} <- Map.fetch(params, :id),
               {:ok, user} <- fetch_user(id) do
            {:ok, user}
          else
            :error -> {:error, :missing_id}
            {:error, reason} -> {:error, reason}
          end
        end
      end
      """

      assert {:ok,
              [
                %{
                  module: Example,
                  function: :load,
                  arity: 1,
                  complexity: 5,
                  coverage_percent: 0,
                  score: 30.0,
                  status: :scored
                }
              ]} =
               ExCrap.analyze_string(source, %{})
    end

    test "scores function with try/else and rescue" do
      source = """
      defmodule Example do
        def parse(value) do
          try do
            decode(value)
          else
            {:ok, decoded} -> decoded
            :error -> nil
          rescue
            ArgumentError -> :bad_argument
          end
        end
      end
      """

      assert {:ok,
              [
                %{
                  module: Example,
                  function: :parse,
                  arity: 1,
                  complexity: 5,
                  coverage_percent: 0,
                  score: 30.0,
                  status: :scored
                }
              ]} =
               ExCrap.analyze_string(source, %{})
    end

    test "scores function with comprehension generators and filters" do
      source = """
      defmodule Example do
        def active_names(users) do
          for user <- users, user.active?, user.confirmed?, do: user.name
        end
      end
      """

      assert {:ok,
              [
                %{
                  module: Example,
                  function: :active_names,
                  arity: 1,
                  complexity: 4,
                  coverage_percent: 0,
                  score: 20.0,
                  status: :scored
                }
              ]} =
               ExCrap.analyze_string(source, %{})
    end

    test "scores function with receive and after" do
      source = """
      defmodule Example do
        def wait do
          receive do
            {:ok, value} -> value
            {:error, reason} -> {:error, reason}
          after
            100 -> :timeout
          end
        end
      end
      """

      assert {:ok,
              [
                %{
                  module: Example,
                  function: :wait,
                  arity: 0,
                  complexity: 4,
                  coverage_percent: 0,
                  score: 20.0,
                  status: :scored
                }
              ]} =
               ExCrap.analyze_string(source, %{})
    end

    test "scores defmacro and defmacrop definitions" do
      source = """
      defmodule Example do
        defmacro debug(value) do
          if value, do: value, else: nil
        end

        defmacrop trace(value) do
          unless value, do: nil
        end
      end
      """

      assert {:ok,
              [
                %{
                  module: Example,
                  function: :debug,
                  arity: 1,
                  complexity: 2,
                  coverage_percent: 0,
                  score: 6.0,
                  status: :scored
                },
                %{
                  module: Example,
                  function: :trace,
                  arity: 1,
                  complexity: 2,
                  coverage_percent: 0,
                  score: 6.0,
                  status: :scored
                }
              ]} = ExCrap.analyze_string(source, %{})
    end
  end
end
