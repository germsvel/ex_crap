defmodule Crap.ComplexityTest do
  use ExUnit.Case, async: true

  describe "from_string/1" do
    test "returns base complexity for a discovered function" do
      source = """
      defmodule Example do
        def greet(name) do
          "hello " <> name
        end
      end
      """

      assert {:ok, [%{module: Example, function: :greet, arity: 1, line: 2, complexity: 1}]} =
               Crap.Complexity.from_string(source)
    end

    test "counts if, unless, and boolean operators as decision points" do
      source = """
      defmodule Example do
        def visible?(user) do
          if user.active and user.confirmed do
            true
          else
            unless user.suspended or user.deleted do
              true
            end
          end
        end
      end
      """

      assert {:ok, results} = Crap.Complexity.from_string(source)
      assert [%{complexity: 5}] = results
    end

    test "counts symbolic boolean operators as decision points" do
      source = """
      defmodule Example do
        def allowed?(user) do
          user.active? && user.confirmed? || user.admin?
        end
      end
      """

      assert {:ok, [%{complexity: 3}]} = Crap.Complexity.from_string(source)
    end

    test "counts guard boolean operators as decision points" do
      source = """
      defmodule Example do
        def valid?(value) when is_binary(value) and byte_size(value) > 0 do
          true
        end
      end
      """

      assert {:ok, [%{complexity: 2}]} = Crap.Complexity.from_string(source)
    end

    test "counts each case branch and cond clause as a decision point" do
      source = """
      defmodule Example do
        def classify(value) do
          case value do
            0 -> :zero
            1 -> :one
            _ -> :many
          end

          cond do
            value < 0 -> :negative
            value > 0 -> :positive
            true -> :zero
          end
        end
      end
      """

      assert {:ok, [%{complexity: 7}]} = Crap.Complexity.from_string(source)
    end

    test "handles multiple functions and aggregates same name and arity clauses" do
      source = """
      defmodule Example do
        def size([]), do: 0
        def size([head | tail]) do
          if head, do: 1 + size(tail), else: size(tail)
        end

        defp hidden(value), do: value
      end
      """

      assert {:ok, results} = Crap.Complexity.from_string(source)

      assert Enum.find(results, &(&1.function == :size)) == %{
               module: Example,
               function: :size,
               arity: 1,
               line: 2,
               complexity: 3
             }

      assert Enum.find(results, &(&1.function == :hidden)) == %{
               module: Example,
               function: :hidden,
               arity: 1,
               line: 7,
               complexity: 1
             }
    end

    test "counts multiple guarded clauses as function-level decision paths" do
      source = """
      defmodule Example do
        def classify(value) when is_integer(value) and value > 0, do: :positive
        def classify(value) when is_integer(value) and value < 0, do: :negative
        def classify(_value), do: :other
      end
      """

      assert {:ok, [%{module: Example, function: :classify, arity: 1, line: 2, complexity: 5}]} =
               Crap.Complexity.from_string(source)
    end

    test "returns an error tuple for invalid Elixir source" do
      assert {:error, :invalid_source} = Crap.Complexity.from_string("defmodule")
    end
  end

  describe "from_file/1" do
    test "parses a realistic Elixir source file without evaluating it" do
      path = Path.expand("../../fixtures/realistic_sample.ex", __DIR__)

      assert {:ok, results} = Crap.Complexity.from_file(path)

      assert Enum.find(results, &(&1.function == :normalize)) == %{
               module: Realistic.Sample,
               function: :normalize,
               arity: 1,
               line: 6,
               complexity: 1
             }

      assert Enum.find(results, &(&1.function == :classify)) == %{
               module: Realistic.Sample,
               function: :classify,
               arity: 1,
               line: 12,
               complexity: 4
             }

      assert Enum.find(results, &(&1.function == :visible?)) == %{
               module: Realistic.Sample,
               function: :visible?,
               arity: 1,
               line: 20,
               complexity: 3
             }

      assert Enum.find(results, &(&1.function == :fallback)) == %{
               module: Realistic.Sample,
               function: :fallback,
               arity: 1,
               line: 28,
               complexity: 4
             }
    end

    test "returns an error tuple for an unreadable file" do
      assert {:error, :enoent} = Crap.Complexity.from_file("test/fixtures/missing.ex")
    end
  end
end
