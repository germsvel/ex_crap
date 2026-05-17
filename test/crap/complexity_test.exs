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

    test "discovers functions defined inside module-level if, else, and unless" do
      source = """
      defmodule Example do
        if true do
          def enabled, do: true
        else
          def disabled, do: false
        end

        unless false do
          def also_enabled, do: true
        end
      end
      """

      assert {:ok, results} = Crap.Complexity.from_string(source)

      assert Enum.map(results, &Map.take(&1, [:module, :function, :arity, :complexity])) == [
               %{module: Example, function: :enabled, arity: 0, complexity: 1},
               %{module: Example, function: :disabled, arity: 0, complexity: 1},
               %{module: Example, function: :also_enabled, arity: 0, complexity: 1}
             ]
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

    test "counts with else clauses as decision points" do
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

      assert {:ok, [%{complexity: 5}]} = Crap.Complexity.from_string(source)
    end

    test "counts try rescue and catch as decision points" do
      source = """
      defmodule Example do
        def safe(fun) do
          try do
            fun.()
          rescue
            ArgumentError -> :bad_argument
            RuntimeError -> :runtime
          catch
            :exit, _reason -> :exit
          after
            :ok
          end
        end
      end
      """

      assert {:ok, [%{complexity: 5}]} = Crap.Complexity.from_string(source)
    end

    test "counts try else clauses as decision points" do
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

      assert {:ok, [%{complexity: 5}]} = Crap.Complexity.from_string(source)
    end

    test "counts comprehension generators and filters as decision points" do
      source = """
      defmodule Example do
        def active_names(users) do
          for user <- users, user.active?, user.confirmed?, do: user.name
        end
      end
      """

      assert {:ok, [%{complexity: 4}]} = Crap.Complexity.from_string(source)
    end

    test "counts receive clauses and after timeout as decision points" do
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

      assert {:ok, [%{complexity: 4}]} = Crap.Complexity.from_string(source)
    end

    test "finds control flow keywords after keyword literals" do
      source = """
      defmodule Example do
        def classify do
          case [ok: true] do
            [ok: true] -> :ok
            _ -> :error
          end

          with [ok: true], false <- true do
            :ok
          else
            _ -> :error
          end
        end
      end
      """

      assert {:ok, [%{complexity: 5}]} = Crap.Complexity.from_string(source)
    end

    test "prefers control flow keyword blocks over matching keyword literals" do
      source = """
      defmodule Example do
        def case_literal do
          case [do: :literal] do
            [do: :literal] -> :ok
            _ -> :error
          end
        end

        def with_literal do
          with [else: :literal], :ok <- :ok do
            :ok
          else
            _ -> :error
          end
        end
      end
      """

      assert {:ok, results} = Crap.Complexity.from_string(source)

      assert Enum.find(results, &(&1.function == :case_literal)).complexity == 3
      assert Enum.find(results, &(&1.function == :with_literal)).complexity == 3
    end

    test "counts boolean decisions in arrow clause guards" do
      source = """
      defmodule Example do
        def guarded(value, flag, other, fun) do
          case value do
            matched when flag and other -> matched
          end

          receive do
            message when flag or other -> message
          after
            0 -> :timeout
          end

          with :ok <- value do
            :ok
          else
            reason when flag and other -> reason
          end

          try do
            fun.()
          rescue
            error in ArgumentError when flag and other -> error
          catch
            kind, reason when flag or other -> {kind, reason}
          end
        end
      end
      """

      assert {:ok, [%{complexity: 14}]} = Crap.Complexity.from_string(source)
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

    test "discovers defmacro and defmacrop definitions" do
      source = """
      defmodule Example do
        defmacro public_macro(value) do
          if value, do: value, else: nil
        end

        defmacrop private_macro(value) do
          unless value, do: nil
        end
      end
      """

      assert {:ok, results} = Crap.Complexity.from_string(source)

      assert Enum.find(results, &(&1.function == :public_macro)) == %{
               module: Example,
               function: :public_macro,
               arity: 1,
               line: 2,
               complexity: 2
             }

      assert Enum.find(results, &(&1.function == :private_macro)) == %{
               module: Example,
               function: :private_macro,
               arity: 1,
               line: 6,
               complexity: 2
             }
    end

    test "does not count nested defmodule body against enclosing function complexity" do
      source = """
      defmodule Outer do
        def outer_fn do
          defmodule Inner do
            def inner_fn do
              if true, do: :yes, else: :no
            end
          end
        end
      end
      """

      assert {:ok, results} = Crap.Complexity.from_string(source)
      outer = Enum.find(results, &(&1.module == Outer and &1.function == :outer_fn))
      assert outer.complexity == 1
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
