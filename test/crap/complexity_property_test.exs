defmodule Crap.ComplexityPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @definition_kinds [:def, :defp, :defmacro, :defmacrop]
  @boolean_operators [:and, :or, :&&, :||]
  @guard_boolean_operators [:and, :or]

  test "nested defimpl resolves targets from grouped aliases" do
    source = """
    defmodule GeneratedGroupedAlias.Scope do
      alias Example.{One, Two}

      defimpl String.Chars, for: One do
        def to_string(value), do: inspect(value)
      end
    end
    """

    assert Crap.Complexity.from_string(source) ==
             {:ok,
              [
                %{
                  module: String.Chars.Example.One,
                  function: :to_string,
                  arity: 1,
                  line: 5,
                  complexity: 1
                }
              ]}
  end

  test "defimpl does not resolve later local target declarations retroactively" do
    source = """
    defmodule GeneratedLocalOrder do
      defprotocol P do
        def to_string(value)
      end

      defimpl P, for: S do
        def to_string(value), do: inspect(value)
      end

      defmodule S do
        defstruct []
      end
    end
    """

    assert Crap.Complexity.from_string(source) ==
             {:ok,
              [
                %{
                  module: GeneratedLocalOrder.P.S,
                  function: :to_string,
                  arity: 1,
                  line: 7,
                  complexity: 1
                }
              ]}
  end

  test "rescue guards are not generated because Elixir rejects them" do
    source = """
    defmodule GeneratedInvalidRescueGuard do
      def run do
        try do
          raise "x"
        rescue
          error in RuntimeError when is_exception(error) -> :ok
        end
      end
    end
    """

    compiler_output =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        assert_raise CompileError, fn ->
          Code.compile_string(source)
        end
      end)

    assert compiler_output =~ ~s(invalid "rescue" clause)
  end

  property "valid generated function bodies cover boolean operators and keep guards guard-valid" do
    check all(operator <- StreamData.member_of(@boolean_operators), max_runs: 20) do
      model = %{
        module: "GeneratedBooleanBody",
        function: "run",
        definition_kind: :def,
        arity: 0,
        clauses: [
          %{
            guard: [:and],
            body: [%{kind: :if, boolean_operators: [operator]}]
          }
        ]
      }

      source = render_valid_function(model)
      expected = expected_result(model)

      assert_analysis(source, model, {:ok, [expected]})
    end
  end

  property "valid generated try clauses use unguarded rescue shapes and guarded catch clauses" do
    check all(
            rescue_branches <- StreamData.integer(1..3),
            catch_guard_operators <-
              StreamData.list_of(guard_operator_sequence(), min_length: 1, max_length: 3),
            max_runs: 20
          ) do
      model = %{
        module: "GeneratedTryGuards",
        function: "run",
        definition_kind: :def,
        arity: 0,
        clauses: [
          %{
            guard: [],
            body: [
              %{
                kind: :try,
                else_branches: 0,
                rescue_branches: rescue_branches,
                catch_branches: length(catch_guard_operators),
                catch_guard_operators: catch_guard_operators
              }
            ]
          }
        ]
      }

      source = render_valid_function(model)
      expected = expected_result(model)

      assert_analysis(source, model, {:ok, [expected]})
    end
  end

  property "valid generated definitions return one row with model-derived complexity" do
    check all(model <- valid_function_model(), max_runs: 50) do
      source = render_valid_function(model)
      expected = expected_result(model)

      assert_analysis(source, model, {:ok, [expected]})
    end
  end

  property "valid generated definitions score unless and cond constructs" do
    check all(model <- valid_function_model(body_constructs: [:unless, :cond]), max_runs: 50) do
      source = render_valid_function(model)
      expected = expected_result(model)

      assert_analysis(source, model, {:ok, [expected]})
    end
  end

  property "valid generated definitions score try for receive and anonymous function constructs" do
    check all(
            model <- valid_function_model(body_constructs: [:try, :for, :receive, :fn]),
            max_runs: 50
          ) do
      source = render_valid_function(model)
      expected = expected_result(model)

      assert_analysis(source, model, {:ok, [expected]})
    end
  end

  property "valid generated definitions score shallow nested body constructs" do
    check all(model <- nested_function_model(), max_runs: 50) do
      source = render_valid_function(model)
      expected = expected_result(model)

      assert_analysis(source, model, {:ok, [expected]})
    end
  end

  property "matching bodyless declaration heads are valid and do not add result rows" do
    check all(model <- valid_declaration_model(), max_runs: 50) do
      source = render_valid_function(model)
      expected = expected_result(model)

      assert_analysis(source, model, {:ok, [expected]})
    end
  end

  property "bodyless declarations without matching implementations are invalid" do
    check all(model <- unmatched_declaration_model(), max_runs: 50) do
      source = render_unmatched_declaration(model)

      assert_analysis(source, model, {:error, :invalid_source})
    end
  end

  property "bodyless declarations implemented by a different definition kind are invalid" do
    check all(model <- wrong_kind_declaration_model(), max_runs: 50) do
      source = render_wrong_kind_declaration(model)

      assert_analysis(source, model, {:error, :invalid_source})
    end
  end

  property "malformed supported definition heads are invalid" do
    check all(model <- malformed_definition_model(), max_runs: 50) do
      source = render_malformed_definition(model)

      assert_analysis(source, model, {:error, :invalid_source})
    end
  end

  property "invalid generated defimpl shapes are invalid" do
    check all(model <- invalid_defimpl_model(), max_runs: 50) do
      source = render_invalid_defimpl(model)

      assert_analysis(source, model, {:error, :invalid_source})
    end
  end

  property "valid non-analyzable source returns no results" do
    check all(model <- non_analyzable_model(), max_runs: 50) do
      source = render_non_analyzable(model)

      assert_analysis(source, model, {:ok, []})
    end
  end

  property "valid generated defimpl blocks return expected protocol target rows" do
    check all(model <- defimpl_model(), max_runs: 50) do
      source = render_defimpl(model)
      expected = expected_defimpl_results(model)

      assert_analysis(source, model, {:ok, expected})
    end
  end

  property "valid generated multi-target defimpl blocks return one row per target" do
    check all(model <- multi_target_defimpl_model(), max_runs: 50) do
      source = render_defimpl(model)
      expected = expected_defimpl_results(model)

      assert_analysis(source, model, {:ok, expected})
    end
  end

  property "valid generated nested modules resolve function result modules" do
    check all(model <- nested_module_model(), max_runs: 50) do
      source = render_nested_module(model)
      expected = expected_nested_module_result(model)

      assert_analysis(source, model, {:ok, [expected]})
    end
  end

  property "valid generated atom-named modules resolve function result modules" do
    check all(model <- atom_module_model(), max_runs: 50) do
      source = render_atom_module(model)
      expected = expected_atom_module_result(model)

      assert_analysis(source, model, {:ok, [expected]})
    end
  end

  property "valid generated Module.concat defimpl forms resolve protocol target modules" do
    check all(model <- module_concat_defimpl_model(), max_runs: 50) do
      source = render_module_concat_defimpl(model)
      expected = expected_module_concat_defimpl_result(model)

      assert_analysis(source, model, {:ok, [expected]})
    end
  end

  property "valid generated nested implicit defimpl forms resolve current module targets" do
    check all(model <- nested_implicit_defimpl_model(), max_runs: 50) do
      source = render_nested_implicit_defimpl(model)
      expected = expected_nested_implicit_defimpl_result(model)

      assert_analysis(source, model, {:ok, [expected]})
    end
  end

  property "valid generated nested defimpl forms resolve local aliases" do
    check all(model <- nested_alias_defimpl_model(), max_runs: 50) do
      source = render_nested_alias_defimpl(model)
      expected = expected_nested_alias_defimpl_result(model)

      assert_analysis(source, model, {:ok, [expected]})
    end
  end

  property "valid generated nested defimpl forms resolve grouped local aliases" do
    check all(model <- nested_grouped_alias_defimpl_model(), max_runs: 50) do
      source = render_nested_grouped_alias_defimpl(model)
      expected = expected_nested_grouped_alias_defimpl_result(model)

      assert_analysis(source, model, {:ok, [expected]})
    end
  end

  property "valid generated nested defimpl forms resolve local protocols and modules" do
    check all(model <- nested_local_defimpl_model(), max_runs: 50) do
      source = render_nested_local_defimpl(model)
      expected = expected_nested_local_defimpl_result(model)

      assert_analysis(source, model, {:ok, [expected]})
    end
  end

  property "invalid generated defmodule names are invalid" do
    check all(model <- invalid_defmodule_model(), max_runs: 50) do
      source = render_invalid_defmodule(model)

      assert_analysis(source, model, {:error, :invalid_source})
    end
  end

  defp valid_function_model, do: valid_function_model(body_constructs: [:if, :case, :with])

  defp valid_function_model(opts) do
    body_constructs = Keyword.fetch!(opts, :body_constructs)

    StreamData.fixed_map(%{
      module: module_name(),
      function: function_name(),
      definition_kind: StreamData.member_of(@definition_kinds),
      arity: StreamData.integer(0..3),
      clauses: clauses(body_constructs)
    })
  end

  defp nested_function_model do
    StreamData.map(
      valid_function_model(body_constructs: [:nested_if_case, :nested_with_cond]),
      fn model ->
        %{model | clauses: Enum.take(model.clauses, 1)}
      end
    )
  end

  defp valid_declaration_model do
    StreamData.map(valid_function_model(), &Map.put(&1, :declaration?, true))
  end

  defp unmatched_declaration_model do
    StreamData.fixed_map(%{
      module: module_name(),
      function: function_name(),
      definition_kind: StreamData.member_of(@definition_kinds),
      arity: StreamData.integer(0..3)
    })
  end

  defp wrong_kind_declaration_model do
    StreamData.bind(StreamData.member_of(@definition_kinds), fn declaration_kind ->
      implementation_kinds = Enum.reject(@definition_kinds, &(&1 == declaration_kind))

      StreamData.fixed_map(%{
        module: module_name(),
        function: function_name(),
        declaration_kind: StreamData.constant(declaration_kind),
        implementation_kind: StreamData.member_of(implementation_kinds),
        arity: StreamData.integer(0..3),
        clauses: clauses([:if, :case, :with])
      })
    end)
  end

  defp malformed_definition_model do
    StreamData.fixed_map(%{
      definition_kind: StreamData.member_of(@definition_kinds),
      with_body?: StreamData.boolean()
    })
  end

  defp invalid_defimpl_model do
    StreamData.member_of([
      %{kind: :invalid_protocol_name},
      %{kind: :invalid_target_name},
      %{kind: :top_level_empty_options},
      %{kind: :missing_top_level_target},
      %{kind: :bodyless_definition}
    ])
  end

  defp non_analyzable_model do
    StreamData.member_of([
      %{kind: :empty_module, module: "GeneratedEmpty"},
      %{kind: :protocol_callbacks, module: "GeneratedProtocol"},
      %{kind: :callback_module, module: "GeneratedBehaviour"}
    ])
  end

  defp defimpl_model do
    StreamData.fixed_map(%{
      protocol: StreamData.member_of(["String.Chars", "Inspect", "Generated.Protocol"]),
      target: StreamData.member_of(["Generated.Target", "Generated.Other"]),
      keyword_form?: StreamData.boolean(),
      function: StreamData.constant("to_string"),
      arity: StreamData.constant(1),
      clauses: clauses([:if, :case, :with, :unless, :cond])
    })
  end

  defp multi_target_defimpl_model do
    StreamData.map(defimpl_model(), fn model ->
      Map.put(model, :targets, ["Generated.One", "Generated.Two"])
    end)
  end

  defp nested_module_model do
    StreamData.fixed_map(%{
      outer: StreamData.constant("GeneratedOuter"),
      inner_form: StreamData.member_of([:alias, :module_alias, :module_concat]),
      function: function_name(),
      arity: StreamData.integer(0..3),
      clauses: clauses([:if, :case, :with, :unless, :cond])
    })
  end

  defp atom_module_model do
    StreamData.fixed_map(%{
      module: StreamData.member_of(["GeneratedAtom", "GeneratedAtom.Nested"]),
      function: function_name(),
      arity: StreamData.integer(0..3),
      clauses: clauses([:if, :case, :with, :unless, :cond])
    })
  end

  defp module_concat_defimpl_model do
    StreamData.fixed_map(%{
      function: StreamData.constant("to_string"),
      arity: StreamData.constant(1),
      clauses: clauses([:if, :case, :with, :unless, :cond])
    })
  end

  defp nested_implicit_defimpl_model do
    StreamData.fixed_map(%{
      protocol: StreamData.member_of(["String.Chars", "Inspect"]),
      target: StreamData.member_of(["GeneratedImplicit", "GeneratedImplicit.Nested"]),
      function: StreamData.constant("to_string"),
      arity: StreamData.constant(1),
      clauses: clauses([:if, :case, :with, :unless, :cond])
    })
  end

  defp nested_alias_defimpl_model do
    StreamData.fixed_map(%{
      protocol: StreamData.member_of(["String.Chars", "Inspect"]),
      protocol_alias: StreamData.constant("ProtocolAlias"),
      target: StreamData.member_of(["GeneratedAlias.Target", "GeneratedAlias.Other"]),
      target_alias: StreamData.constant("TargetAlias"),
      function: StreamData.constant("to_string"),
      arity: StreamData.constant(1),
      clauses: clauses([:if, :case, :with, :unless, :cond])
    })
  end

  defp nested_grouped_alias_defimpl_model do
    StreamData.fixed_map(%{
      protocol: StreamData.member_of(["String.Chars", "Inspect"]),
      target_alias: StreamData.member_of(["One", "Two", "One.Nested"]),
      function: StreamData.constant("to_string"),
      arity: StreamData.constant(1),
      clauses: clauses([:if, :case, :with, :unless, :cond])
    })
  end

  defp nested_local_defimpl_model do
    StreamData.fixed_map(%{
      outer: StreamData.constant("GeneratedLocal"),
      protocol: StreamData.member_of(["P", "Protocol.Nested"]),
      target: StreamData.member_of(["S", "Target.Nested"]),
      function: StreamData.constant("to_string"),
      arity: StreamData.constant(1),
      clauses: clauses([:if, :case, :with, :unless, :cond])
    })
  end

  defp invalid_defmodule_model do
    StreamData.member_of([
      %{kind: :integer_name},
      %{kind: :tuple_name},
      %{kind: :list_name},
      %{kind: :keyword_name},
      %{kind: :empty_options}
    ])
  end

  defp module_name do
    StreamData.member_of(["GeneratedExample", "GeneratedExample.One", "GeneratedExample.Two"])
  end

  defp function_name do
    StreamData.member_of(["run", "classify", "build", "visible?"])
  end

  defp clauses(body_constructs) do
    StreamData.list_of(clause(body_constructs), min_length: 1, max_length: 3)
  end

  defp clause(body_constructs) do
    StreamData.fixed_map(%{
      guard: guard_operator_sequence(),
      body: StreamData.list_of(body_construct(body_constructs), min_length: 0, max_length: 3)
    })
  end

  defp body_construct(kinds) do
    kinds
    |> Enum.map(&construct_generator/1)
    |> StreamData.one_of()
  end

  defp construct_generator(:if),
    do: StreamData.map(operator_sequence(), &%{kind: :if, boolean_operators: &1})

  defp construct_generator(:unless),
    do: StreamData.map(operator_sequence(), &%{kind: :unless, boolean_operators: &1})

  defp construct_generator(:case) do
    StreamData.fixed_map(%{
      kind: StreamData.constant(:case),
      branches: StreamData.integer(1..3),
      clause_guard_operators:
        StreamData.list_of(guard_operator_sequence(), min_length: 0, max_length: 3)
    })
  end

  defp construct_generator(:cond) do
    StreamData.fixed_map(%{
      kind: StreamData.constant(:cond),
      branches: StreamData.integer(1..3),
      clause_guard_operators:
        StreamData.list_of(operator_sequence(), min_length: 0, max_length: 3)
    })
  end

  defp construct_generator(:with) do
    StreamData.fixed_map(%{
      kind: StreamData.constant(:with),
      generators: StreamData.integer(1..3),
      else_branches: StreamData.integer(0..3),
      else_guard_operators:
        StreamData.list_of(guard_operator_sequence(), min_length: 0, max_length: 3)
    })
  end

  defp construct_generator(:try) do
    StreamData.fixed_map(%{
      kind: StreamData.constant(:try),
      else_branches: StreamData.integer(0..3),
      rescue_branches: StreamData.integer(0..3),
      catch_branches: StreamData.integer(0..3),
      catch_guard_operators:
        StreamData.list_of(guard_operator_sequence(), min_length: 0, max_length: 3)
    })
  end

  defp construct_generator(:for) do
    StreamData.fixed_map(%{
      kind: StreamData.constant(:for),
      generators: StreamData.integer(1..3),
      filters: StreamData.integer(0..3),
      reduce?: StreamData.boolean()
    })
  end

  defp construct_generator(:receive) do
    StreamData.fixed_map(%{
      kind: StreamData.constant(:receive),
      branches: StreamData.integer(1..3),
      clause_guard_operators:
        StreamData.list_of(guard_operator_sequence(), min_length: 0, max_length: 3),
      after?: StreamData.boolean()
    })
  end

  defp construct_generator(:fn) do
    StreamData.fixed_map(%{
      kind: StreamData.constant(:fn),
      clauses: StreamData.integer(1..3),
      clause_guard_operators:
        StreamData.list_of(guard_operator_sequence(), min_length: 0, max_length: 3)
    })
  end

  defp construct_generator(:nested_if_case) do
    StreamData.fixed_map(%{
      kind: StreamData.constant(:nested_if_case),
      if_operators: operator_sequence(),
      case_branches: StreamData.integer(1..3),
      case_guard_operators:
        StreamData.list_of(guard_operator_sequence(), min_length: 0, max_length: 3)
    })
  end

  defp construct_generator(:nested_with_cond) do
    StreamData.fixed_map(%{
      kind: StreamData.constant(:nested_with_cond),
      with_generators: StreamData.integer(1..3),
      cond_branches: StreamData.integer(1..3),
      cond_guard_operators: StreamData.list_of(operator_sequence(), min_length: 0, max_length: 3)
    })
  end

  defp operator_sequence do
    StreamData.list_of(StreamData.member_of(@boolean_operators), min_length: 0, max_length: 2)
  end

  defp guard_operator_sequence do
    StreamData.list_of(StreamData.member_of(@guard_boolean_operators),
      min_length: 0,
      max_length: 2
    )
  end

  defp render_valid_function(model) do
    declarations =
      if Map.get(model, :declaration?, false),
        do: [render_head(model.definition_kind, model)],
        else: []

    implementations = Enum.map(model.clauses, &render_clause(model.definition_kind, model, &1))

    render_module(model.module, declarations ++ implementations)
  end

  defp render_unmatched_declaration(model) do
    render_module(model.module, [render_head(model.definition_kind, model)])
  end

  defp render_wrong_kind_declaration(model) do
    render_module(
      model.module,
      [render_head(model.declaration_kind, model)] ++
        Enum.map(model.clauses, &render_clause(model.implementation_kind, model, &1))
    )
  end

  defp render_non_analyzable(%{kind: :empty_module, module: module}) do
    render_module(module, [])
  end

  defp render_non_analyzable(%{kind: :protocol_callbacks, module: module}) do
    """
    defprotocol #{module} do
      def call(value)
      def render(value, opts)
    end
    """
  end

  defp render_non_analyzable(%{kind: :callback_module, module: module}) do
    render_module(module, ["@callback call(term()) :: term()"])
  end

  defp render_defimpl(%{targets: targets} = model) do
    target_source = "[#{Enum.join(targets, ", ")}]"
    render_defimpl_body(model, target_source)
  end

  defp render_defimpl(model) do
    render_defimpl_body(model, model.target)
  end

  defp render_defimpl_body(%{keyword_form?: true} = model, target_source) do
    clause = List.first(model.clauses)

    """
    defimpl #{model.protocol}, for: #{target_source}, do: def(#{model.function}(#{arguments(model.arity)})#{render_guard(clause.guard)}, do: :ok)
    """
  end

  defp render_defimpl_body(model, target_source) do
    implementations = Enum.map(model.clauses, &render_clause(:def, model, &1))

    """
    defimpl #{model.protocol}, for: #{target_source} do
    #{indent(Enum.join(implementations, "\n"), 2)}
    end
    """
  end

  defp render_nested_module(model) do
    inner_source =
      case model.inner_form do
        :alias -> "GeneratedInner"
        :module_alias -> "__MODULE__.GeneratedInner"
        :module_concat -> "Module.concat(__MODULE__, GeneratedInner)"
      end

    body_model = Map.put(model, :module, "GeneratedOuter.GeneratedInner")
    implementations = Enum.map(model.clauses, &render_clause(:def, body_model, &1))

    """
    defmodule #{model.outer} do
      defmodule #{inner_source} do
    #{indent(Enum.join(implementations, "\n"), 4)}
      end
    end
    """
  end

  defp render_atom_module(model) do
    body_model = Map.put(model, :module, model.module)
    implementations = Enum.map(model.clauses, &render_clause(:def, body_model, &1))

    render_module(~s(:"Elixir.#{model.module}"), implementations)
  end

  defp render_module_concat_defimpl(model) do
    implementations = Enum.map(model.clauses, &render_clause(:def, model, &1))

    """
    defimpl Module.concat(String, Chars), for: Module.concat(Generated, Target) do
    #{indent(Enum.join(implementations, "\n"), 2)}
    end
    """
  end

  defp render_nested_implicit_defimpl(model) do
    implementations = Enum.map(model.clauses, &render_clause(:def, model, &1))

    """
    defmodule #{model.target} do
      defimpl #{model.protocol} do
    #{indent(Enum.join(implementations, "\n"), 4)}
      end
    end
    """
  end

  defp render_nested_alias_defimpl(model) do
    implementations = Enum.map(model.clauses, &render_clause(:def, model, &1))

    """
    defmodule GeneratedAlias.Scope do
      alias #{model.protocol}, as: #{model.protocol_alias}
      alias #{model.target}, as: #{model.target_alias}

      defimpl #{model.protocol_alias}, for: #{model.target_alias} do
    #{indent(Enum.join(implementations, "\n"), 4)}
      end
    end
    """
  end

  defp render_nested_grouped_alias_defimpl(model) do
    implementations = Enum.map(model.clauses, &render_clause(:def, model, &1))

    """
    defmodule GeneratedGroupedAlias.Scope do
      alias Example.{One, Two}

      defimpl #{model.protocol}, for: #{model.target_alias} do
    #{indent(Enum.join(implementations, "\n"), 4)}
      end
    end
    """
  end

  defp render_nested_local_defimpl(model) do
    implementations = Enum.map(model.clauses, &render_clause(:def, model, &1))

    """
    defmodule #{model.outer} do
      defprotocol #{model.protocol} do
        def #{model.function}(value)
      end

      defmodule #{model.target} do
        defstruct []
      end

      defimpl #{model.protocol}, for: #{model.target} do
    #{indent(Enum.join(implementations, "\n"), 4)}
      end
    end
    """
  end

  defp render_invalid_defmodule(%{kind: :integer_name}) do
    "defmodule 123 do\n  def run, do: :ok\nend"
  end

  defp render_invalid_defmodule(%{kind: :tuple_name}) do
    "defmodule {:bad, :name} do\n  def run, do: :ok\nend"
  end

  defp render_invalid_defmodule(%{kind: :list_name}) do
    "defmodule [:bad, :name] do\n  def run, do: :ok\nend"
  end

  defp render_invalid_defmodule(%{kind: :keyword_name}) do
    "defmodule [as: BadName] do\n  def run, do: :ok\nend"
  end

  defp render_invalid_defmodule(%{kind: :empty_options}) do
    "defmodule [] do\n  def run, do: :ok\nend"
  end

  defp render_malformed_definition(%{definition_kind: kind, with_body?: false}) do
    render_module("GeneratedBad", ["#{kind} 123"])
  end

  defp render_malformed_definition(%{definition_kind: kind, with_body?: true}) do
    render_module("GeneratedBad", ["#{kind} 123 do\n  :ok\nend"])
  end

  defp render_invalid_defimpl(%{kind: :invalid_protocol_name}) do
    "defimpl 123, for: Generated.Target do\n  def to_string(_), do: :ok\nend"
  end

  defp render_invalid_defimpl(%{kind: :invalid_target_name}) do
    "defimpl String.Chars, for: 123 do\n  def to_string(_), do: :ok\nend"
  end

  defp render_invalid_defimpl(%{kind: :top_level_empty_options}) do
    "defimpl String.Chars, [] do\n  def to_string(_), do: :ok\nend"
  end

  defp render_invalid_defimpl(%{kind: :missing_top_level_target}) do
    "defimpl String.Chars do\n  def to_string(_), do: :ok\nend"
  end

  defp render_invalid_defimpl(%{kind: :bodyless_definition}) do
    "defimpl String.Chars, for: Generated.Target do\n  def to_string(value)\nend"
  end

  defp render_module(module, lines) do
    body = lines |> Enum.map(&"  #{&1}") |> Enum.join("\n")

    """
    defmodule #{module} do
    #{body}
    end
    """
  end

  defp render_head(kind, model) do
    "#{kind} #{model.function}(#{arguments(model.arity)})"
  end

  defp render_clause(kind, model, clause) do
    guard = render_guard(clause.guard)

    """
    #{kind} #{model.function}(#{arguments(model.arity)})#{guard} do
    #{render_body(clause.body)}
    end
    """
    |> String.trim_trailing()
  end

  defp render_guard([]), do: ""
  defp render_guard(operators), do: " when " <> boolean_chain(operators)

  defp render_body([]), do: "  :ok"

  defp render_body(constructs) do
    constructs
    |> Enum.map(&render_construct/1)
    |> Enum.join("\n")
    |> String.split("\n")
    |> Enum.map_join("\n", &"  #{&1}")
  end

  defp render_construct(%{kind: :if, boolean_operators: operators}) do
    """
    if #{boolean_chain(operators)} do
      :ok
    else
      :error
    end
    """
    |> String.trim_trailing()
  end

  defp render_construct(%{kind: :unless, boolean_operators: operators}) do
    """
    unless #{boolean_chain(operators)} do
      :ok
    else
      :error
    end
    """
    |> String.trim_trailing()
  end

  defp render_construct(%{
         kind: :case,
         branches: branches,
         clause_guard_operators: guard_operators
       }) do
    clauses =
      1..branches
      |> Enum.map(fn index ->
        operators = Enum.at(guard_operators, index - 1, [])

        "#{index}#{render_guard(operators)} -> :branch_#{index}"
      end)
      |> Enum.join("\n")

    """
    case value do
    #{indent(clauses, 2)}
    end
    """
    |> String.trim_trailing()
  end

  defp render_construct(%{
         kind: :cond,
         branches: branches,
         clause_guard_operators: guard_operators
       }) do
    clauses =
      1..branches
      |> Enum.map(fn index ->
        operators = Enum.at(guard_operators, index - 1, [])
        "#{boolean_chain(operators)} -> :branch_#{index}"
      end)
      |> Enum.join("\n")

    """
    cond do
    #{indent(clauses, 2)}
    end
    """
    |> String.trim_trailing()
  end

  defp render_construct(%{kind: :with} = construct) do
    generators =
      1..construct.generators
      |> Enum.map_join(",\n", fn index -> ":ok <- step_#{index}" end)

    else_block = render_with_else(construct.else_branches, construct.else_guard_operators)

    """
    with #{generators} do
      :ok
    #{else_block}end
    """
    |> String.trim_trailing()
  end

  defp render_construct(%{kind: :try} = construct) do
    """
    try do
      :ok
    #{render_try_else(construct.else_branches)}#{render_try_rescue(construct.rescue_branches)}#{render_try_catch(construct.catch_branches, construct.catch_guard_operators)}end
    """
    |> String.trim_trailing()
  end

  defp render_construct(%{kind: :for} = construct) do
    qualifiers =
      Enum.map_join(1..construct.generators, ", ", fn index -> "item_#{index} <- items" end)

    filters =
      if construct.filters == 0 do
        ""
      else
        1..construct.filters
        |> Enum.map(fn index -> "filter_#{index}" end)
        |> Enum.join(", ")
      end

    qualifier_source = Enum.reject([qualifiers, filters], &(&1 == "")) |> Enum.join(", ")

    if construct.reduce? do
      """
      for #{qualifier_source}, reduce: [] do
        acc -> acc
      end
      """
    else
      """
      for #{qualifier_source}, do: :ok
      """
    end
    |> String.trim_trailing()
  end

  defp render_construct(%{kind: :receive} = construct) do
    clauses =
      1..construct.branches
      |> Enum.map(fn index ->
        operators = Enum.at(construct.clause_guard_operators, index - 1, [])
        "{:message, #{index}}#{render_guard(operators)} -> :message_#{index}"
      end)
      |> Enum.join("\n")

    """
    receive do
    #{indent(clauses, 2)}
    #{render_receive_after(construct.after?)}end
    """
    |> String.trim_trailing()
  end

  defp render_construct(%{kind: :fn} = construct) do
    clauses =
      1..construct.clauses
      |> Enum.map(fn index ->
        operators = Enum.at(construct.clause_guard_operators, index - 1, [])
        "#{index}#{render_guard(operators)} -> :clause_#{index}"
      end)
      |> Enum.join("\n")

    """
    fn
    #{indent(clauses, 2)}
    end
    """
    |> String.trim_trailing()
  end

  defp render_construct(%{kind: :nested_if_case} = construct) do
    clauses =
      1..construct.case_branches
      |> Enum.map(fn index ->
        operators = Enum.at(construct.case_guard_operators, index - 1, [])
        "#{index}#{render_guard(operators)} -> :branch_#{index}"
      end)
      |> Enum.join("\n")

    """
    if #{boolean_chain(construct.if_operators)} do
      case value do
    #{indent(clauses, 4)}
      end
    else
      :error
    end
    """
    |> String.trim_trailing()
  end

  defp render_construct(%{kind: :nested_with_cond} = construct) do
    generators = Enum.map_join(1..construct.with_generators, ",\n", &":ok <- nested_step_#{&1}")

    clauses =
      1..construct.cond_branches
      |> Enum.map(fn index ->
        operators = Enum.at(construct.cond_guard_operators, index - 1, [])
        "#{boolean_chain(operators)} -> :branch_#{index}"
      end)
      |> Enum.join("\n")

    """
    with #{generators} do
      cond do
    #{indent(clauses, 4)}
      end
    end
    """
    |> String.trim_trailing()
  end

  defp render_try_else(0), do: ""

  defp render_try_else(branches) do
    clauses = Enum.map_join(1..branches, "\n", &":ok -> :else_#{&1}")
    "else\n#{indent(clauses, 2)}\n"
  end

  defp render_try_rescue(0), do: ""

  defp render_try_rescue(branches) do
    clauses =
      1..branches
      |> Enum.map(fn index ->
        "error in RuntimeError -> {:rescue, error, #{index}}"
      end)
      |> Enum.join("\n")

    "rescue\n#{indent(clauses, 2)}\n"
  end

  defp render_try_catch(0, _guard_operators), do: ""

  defp render_try_catch(branches, guard_operators) do
    clauses =
      1..branches
      |> Enum.map(fn index ->
        operators = Enum.at(guard_operators, index - 1, [])
        "kind, reason#{render_guard(operators)} -> {:catch, kind, reason, #{index}}"
      end)
      |> Enum.join("\n")

    "catch\n#{indent(clauses, 2)}\n"
  end

  defp render_receive_after(false), do: ""

  defp render_receive_after(true) do
    "after\n  0 -> :timeout\n"
  end

  defp render_with_else(0, _guard_operators), do: ""

  defp render_with_else(branches, guard_operators) do
    clauses =
      1..branches
      |> Enum.map(fn index ->
        operators = Enum.at(guard_operators, index - 1, [])

        ":error#{render_guard(operators)} -> :error_#{index}"
      end)
      |> Enum.join("\n")

    "else\n#{indent(clauses, 2)}\n"
  end

  defp boolean_chain([]), do: "flag"

  defp boolean_chain(operators) do
    operands = ["flag" | Enum.map(1..length(operators), &"flag_#{&1}")]

    operators
    |> Enum.zip(tl(operands))
    |> Enum.reduce(hd(operands), fn {operator, operand}, source ->
      "#{source} #{operator} #{operand}"
    end)
  end

  defp arguments(0), do: ""

  defp arguments(arity) do
    1..arity
    |> Enum.map_join(", ", &"arg#{&1}")
  end

  defp expected_result(model) do
    expected_row(
      Module.concat([model.module]),
      String.to_atom(model.function),
      model.arity,
      expected_line(model),
      expected_complexity(model)
    )
  end

  defp expected_line(%{declaration?: true}), do: 3
  defp expected_line(_model), do: 2

  defp expected_complexity(model), do: clauses_complexity(model.clauses)

  defp expected_defimpl_results(%{targets: targets} = model) do
    targets
    |> Enum.map(&expected_defimpl_result(model, &1))
    |> Enum.sort_by(&{inspect(&1.module), &1.line || 0, &1.function, &1.arity})
  end

  defp expected_defimpl_results(model), do: [expected_defimpl_result(model, model.target)]

  defp expected_defimpl_result(model, target) do
    clauses = if model.keyword_form?, do: Enum.take(model.clauses, 1), else: model.clauses

    complexity =
      if model.keyword_form? do
        clause = List.first(clauses)
        1 + length(clause.guard)
      else
        clauses_complexity(clauses)
      end

    expected_row(
      Module.concat([Module.concat([model.protocol]), Module.concat([target])]),
      String.to_atom(model.function),
      model.arity,
      if(model.keyword_form?, do: 1, else: 2),
      complexity
    )
  end

  defp expected_nested_module_result(model) do
    expected_row(
      GeneratedOuter.GeneratedInner,
      String.to_atom(model.function),
      model.arity,
      3,
      clauses_complexity(model.clauses)
    )
  end

  defp expected_atom_module_result(model) do
    expected_row(
      Module.concat([model.module]),
      String.to_atom(model.function),
      model.arity,
      2,
      clauses_complexity(model.clauses)
    )
  end

  defp expected_module_concat_defimpl_result(model) do
    expected_row(
      String.Chars.Generated.Target,
      :to_string,
      1,
      2,
      clauses_complexity(model.clauses)
    )
  end

  defp expected_nested_implicit_defimpl_result(model) do
    expected_row(
      Module.concat([Module.concat([model.protocol]), Module.concat([model.target])]),
      :to_string,
      1,
      3,
      clauses_complexity(model.clauses)
    )
  end

  defp expected_nested_alias_defimpl_result(model) do
    expected_row(
      Module.concat([Module.concat([model.protocol]), Module.concat([model.target])]),
      :to_string,
      1,
      6,
      clauses_complexity(model.clauses)
    )
  end

  defp expected_nested_grouped_alias_defimpl_result(model) do
    expected_row(
      Module.concat([
        Module.concat([model.protocol]),
        Module.concat(["Example", model.target_alias])
      ]),
      :to_string,
      1,
      5,
      clauses_complexity(model.clauses)
    )
  end

  defp expected_nested_local_defimpl_result(model) do
    expected_row(
      Module.concat([
        Module.concat([model.outer, model.protocol]),
        Module.concat([model.outer, model.target])
      ]),
      :to_string,
      1,
      11,
      clauses_complexity(model.clauses)
    )
  end

  defp expected_row(module, function, arity, line, complexity) do
    %{
      module: module,
      function: function,
      arity: arity,
      line: line,
      complexity: complexity
    }
  end

  defp clauses_complexity(clauses) do
    Enum.reduce(clauses, 0, fn clause, total ->
      total + 1 + length(clause.guard) + Enum.reduce(clause.body, 0, &(&2 + construct_score(&1)))
    end)
  end

  defp construct_score(%{kind: :if, boolean_operators: operators}), do: 1 + length(operators)

  defp construct_score(%{kind: :unless, boolean_operators: operators}), do: 1 + length(operators)

  defp construct_score(%{
         kind: :case,
         branches: branches,
         clause_guard_operators: guard_operators
       }) do
    branches + guard_score(guard_operators, branches)
  end

  defp construct_score(%{
         kind: :cond,
         branches: branches,
         clause_guard_operators: guard_operators
       }) do
    branches + guard_score(guard_operators, branches)
  end

  defp construct_score(%{kind: :with} = construct) do
    construct.generators + construct.else_branches +
      guard_score(construct.else_guard_operators, construct.else_branches)
  end

  defp construct_score(%{kind: :try} = construct) do
    1 + construct.else_branches + construct.rescue_branches + construct.catch_branches +
      guard_score(construct.catch_guard_operators, construct.catch_branches)
  end

  defp construct_score(%{kind: :for} = construct) do
    construct.generators + construct.filters
  end

  defp construct_score(%{kind: :receive} = construct) do
    after_score = if construct.after?, do: 1, else: 0

    construct.branches + after_score +
      guard_score(construct.clause_guard_operators, construct.branches)
  end

  defp construct_score(%{kind: :fn} = construct) do
    construct.clauses + guard_score(construct.clause_guard_operators, construct.clauses)
  end

  defp construct_score(%{kind: :nested_if_case} = construct) do
    1 + length(construct.if_operators) + construct.case_branches +
      guard_score(construct.case_guard_operators, construct.case_branches)
  end

  defp construct_score(%{kind: :nested_with_cond} = construct) do
    construct.with_generators + construct.cond_branches +
      guard_score(construct.cond_guard_operators, construct.cond_branches)
  end

  defp guard_score(guard_operators, rendered_clause_count) do
    guard_operators
    |> Enum.take(rendered_clause_count)
    |> Enum.reduce(0, &(&2 + length(&1)))
  end

  defp indent(text, spaces) do
    padding = String.duplicate(" ", spaces)

    text
    |> String.split("\n")
    |> Enum.map_join("\n", &(padding <> &1))
  end

  defp assert_analysis(source, model, expected) do
    actual = Crap.Complexity.from_string(source)

    assert actual == expected,
           """
           Expected #{inspect(expected)}, got #{inspect(actual)}

           Source:
           #{source}

           Model:
           #{inspect(model, pretty: true)}
           """
  end
end
