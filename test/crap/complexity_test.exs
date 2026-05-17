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

    test "returns an empty result for a protocol with callback declarations" do
      source = """
      defprotocol Example.Protocol do
        def call(value)
        def render(session, opts)
      end
      """

      assert Crap.Complexity.from_string(source) == {:ok, []}
    end

    test "returns an empty result for a callback-only module" do
      source = """
      defmodule Example.Behaviour do
        @callback call(term()) :: term()
      end
      """

      assert Crap.Complexity.from_string(source) == {:ok, []}
    end

    test "returns an empty result for an empty valid module" do
      source = """
      defmodule Example.Empty do
      end
      """

      assert Crap.Complexity.from_string(source) == {:ok, []}
    end

    test "analyzes functions inside defimpl blocks" do
      source = """
      defimpl String.Chars, for: Example do
        def to_string(value) do
          if value, do: "yes", else: "no"
        end
      end
      """

      assert {:ok,
              [
                %{
                  module: String.Chars.Example,
                  function: :to_string,
                  arity: 1,
                  complexity: 2
                }
              ]} = Crap.Complexity.from_string(source)
    end

    test "analyzes keyword-form defimpl blocks" do
      source = ~S"""
      defimpl String.Chars, for: Example, do: def(to_string(_), do: "ok")
      """

      assert {:ok,
              [
                %{
                  module: String.Chars.Example,
                  function: :to_string,
                  arity: 1,
                  complexity: 1
                }
              ]} = Crap.Complexity.from_string(source)
    end

    test "analyzes defimpl blocks for multiple target modules" do
      source = """
      defimpl String.Chars, for: [Example.One, Example.Two] do
        def to_string(value), do: inspect(value)
      end
      """

      assert {:ok, results} = Crap.Complexity.from_string(source)

      assert Enum.map(results, &Map.take(&1, [:module, :function, :arity, :complexity])) == [
               %{module: String.Chars.Example.One, function: :to_string, arity: 1, complexity: 1},
               %{module: String.Chars.Example.Two, function: :to_string, arity: 1, complexity: 1}
             ]
    end

    test "analyzes nested defimpl blocks without explicit for target" do
      source = """
      defmodule Example do
        defimpl String.Chars do
          def to_string(value), do: inspect(value)
        end
      end
      """

      assert {:ok,
              [
                %{
                  module: String.Chars.Example,
                  function: :to_string,
                  arity: 1,
                  complexity: 1
                }
              ]} = Crap.Complexity.from_string(source)
    end

    test "analyzes nested defimpl blocks with empty options as implicit for current module" do
      source = """
      defmodule Outer do
        defprotocol P do
          def x(v)
        end

        defimpl P, [] do
          def x(_), do: :ok
        end
      end
      """

      assert {:ok,
              [
                %{
                  module: Outer.P.Outer,
                  function: :x,
                  arity: 1,
                  complexity: 1
                }
              ]} = Crap.Complexity.from_string(source)
    end

    test "scopes local protocol aliases in nested explicit defimpl blocks" do
      source = """
      defmodule Outer do
        defprotocol P do
          def x(v)
        end

        defmodule S do
          defstruct []
        end

        defimpl P, for: S do
          def x(_), do: :ok
        end
      end
      """

      assert {:ok,
              [
                %{
                  module: Outer.P.Outer.S,
                  function: :x,
                  arity: 1,
                  complexity: 1
                }
              ]} = Crap.Complexity.from_string(source)
    end

    test "scopes local multi-part protocol aliases in nested explicit defimpl blocks" do
      source = """
      defmodule Outer do
        defprotocol P.Q do
          def x(v)
        end

        defmodule S do
          defstruct []
        end

        defimpl P.Q, for: S do
          def x(_), do: :ok
        end
      end
      """

      assert {:ok,
              [
                %{
                  module: Outer.P.Q.Outer.S,
                  function: :x,
                  arity: 1,
                  complexity: 1
                }
              ]} = Crap.Complexity.from_string(source)
    end

    test "keeps multi-part protocol aliases absolute in nested explicit defimpl blocks" do
      source = """
      defmodule Outer do
        defmodule S do
          defstruct []
        end

        defimpl String.Chars, for: S do
          def to_string(_), do: "ok"
        end
      end
      """

      assert {:ok,
              [
                %{
                  module: String.Chars.Outer.S,
                  function: :to_string,
                  arity: 1,
                  complexity: 1
                }
              ]} = Crap.Complexity.from_string(source)
    end

    test "keeps undeclared multi-part target aliases absolute in nested explicit defimpl blocks" do
      source = """
      defmodule Outer do
        defimpl String.Chars, for: Example.One do
          def to_string(_), do: "ok"
        end
      end
      """

      assert {:ok,
              [
                %{
                  module: String.Chars.Example.One,
                  function: :to_string,
                  arity: 1,
                  complexity: 1
                }
              ]} = Crap.Complexity.from_string(source)
    end

    test "allows default-argument function heads before implementation clauses" do
      source = ~S"""
      defmodule Example do
        def check(session, label, opts \\ [exact: true])

        def check(session, label, opts) when is_binary(label) and is_list(opts) do
          {session, label, opts}
        end
      end
      """

      assert {:ok,
              [
                %{
                  module: Example,
                  function: :check,
                  arity: 3,
                  line: 4,
                  complexity: 2
                }
              ]} = Crap.Complexity.from_string(source)
    end

    test "allows bodyless declaration heads when implementation clauses exist" do
      source = """
      defmodule Example do
        def assert_has(session, selector, opts_or_text)

        def assert_has(session, selector, opts) when is_list(opts) do
          {session, selector, opts}
        end

        def assert_has(session, selector, text) do
          {session, selector, text}
        end
      end
      """

      assert {:ok,
              [
                %{
                  module: Example,
                  function: :assert_has,
                  arity: 3,
                  line: 4,
                  complexity: 2
                }
              ]} = Crap.Complexity.from_string(source)
    end

    test "returns an error tuple for bodyless supported definitions inside modules" do
      for definition <- ["def", "defp", "defmacro", "defmacrop"] do
        source = """
        defmodule Bad do
          #{definition} run(arg)
        end
        """

        assert {:error, :invalid_source} = Crap.Complexity.from_string(source)
      end
    end

    test "returns an error tuple for bodyless supported definitions inside defimpl blocks" do
      for definition <- ["def", "defp", "defmacro", "defmacrop"] do
        source = """
        defimpl String.Chars, for: Example do
          #{definition} run(arg)
        end
        """

        assert {:error, :invalid_source} = Crap.Complexity.from_string(source)
      end
    end

    test "returns an error tuple for malformed supported definition heads" do
      for definition <- ["def", "defp", "defmacro", "defmacrop"] do
        bodyless_source = """
        defmodule Bad do
          #{definition} 123
        end
        """

        bodied_source = """
        defmodule Bad do
          #{definition} 123 do
            :ok
          end
        end
        """

        assert {:error, :invalid_source} = Crap.Complexity.from_string(bodyless_source)
        assert {:error, :invalid_source} = Crap.Complexity.from_string(bodied_source)
      end
    end

    test "returns an error tuple for incomplete supported executable containers" do
      assert {:error, :invalid_source} = Crap.Complexity.from_string("defmodule Foo")

      assert {:error, :invalid_source} =
               Crap.Complexity.from_string("defimpl String.Chars, for: Example")
    end

    test "returns an error tuple for invalid supported executable container names" do
      assert {:error, :invalid_source} =
               Crap.Complexity.from_string("defmodule 123 do\nend")

      assert {:error, :invalid_source} =
               Crap.Complexity.from_string("defimpl 123, for: Example do\nend")

      assert {:error, :invalid_source} =
               Crap.Complexity.from_string("defimpl String.Chars, for: 123 do\nend")
    end

    test "returns an error tuple for unsupported defimpl shapes" do
      source = """
      defimpl String.Chars do
      end
      """

      assert {:error, :invalid_source} = Crap.Complexity.from_string(source)
    end

    test "returns an error tuple for top-level defimpl blocks with empty options" do
      source = """
      defimpl String.Chars, [] do
        def to_string(_), do: "ok"
      end
      """

      assert {:error, :invalid_source} = Crap.Complexity.from_string(source)
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

    test "parses new AST shapes in the realistic fixture" do
      path = Path.expand("../../fixtures/realistic_sample.ex", __DIR__)

      assert {:ok, results} = Crap.Complexity.from_file(path)

      assert %{module: Realistic.Sample, function: :fetch, arity: 2, complexity: 5} =
               Enum.find(results, &(&1.function == :fetch))

      assert %{module: Realistic.Sample, function: :process, arity: 1, complexity: 4} =
               Enum.find(results, &(&1.function == :process))

      assert %{module: Realistic.Sample, function: :load, arity: 2, complexity: 5} =
               Enum.find(results, &(&1.function == :load))

      assert %{module: Realistic.Sample, function: :assert_valid, arity: 1, complexity: 2} =
               Enum.find(results, &(&1.function == :assert_valid))
    end

    test "returns an error tuple for an unreadable file" do
      assert {:error, :enoent} = Crap.Complexity.from_file("test/fixtures/missing.ex")
    end
  end
end
