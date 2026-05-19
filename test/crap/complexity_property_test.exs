defmodule Crap.ComplexityPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @definition_kinds [:def, :defp, :defmacro, :defmacrop]
  @boolean_operators [:and, :or, :&&, :||]

  property "valid generated definitions return one row with model-derived complexity" do
    check all(model <- valid_function_model(), max_runs: 50) do
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

  property "valid non-analyzable source returns no results" do
    check all(model <- non_analyzable_model(), max_runs: 50) do
      source = render_non_analyzable(model)

      assert_analysis(source, model, {:ok, []})
    end
  end

  defp valid_function_model do
    StreamData.fixed_map(%{
      module: module_name(),
      function: function_name(),
      definition_kind: StreamData.member_of(@definition_kinds),
      arity: StreamData.integer(0..3),
      declaration?: StreamData.constant(false),
      clauses: clauses()
    })
  end

  defp valid_declaration_model do
    StreamData.map(valid_function_model(), &%{&1 | declaration?: true})
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
        clauses: clauses()
      })
    end)
  end

  defp non_analyzable_model do
    StreamData.member_of([
      %{kind: :empty_module, module: "GeneratedEmpty"},
      %{kind: :protocol_callbacks, module: "GeneratedProtocol"},
      %{kind: :callback_module, module: "GeneratedBehaviour"}
    ])
  end

  defp module_name do
    StreamData.member_of(["GeneratedExample", "GeneratedExample.One", "GeneratedExample.Two"])
  end

  defp function_name do
    StreamData.member_of(["run", "classify", "build", "visible?"])
  end

  defp clauses do
    StreamData.list_of(clause(), min_length: 1, max_length: 3)
  end

  defp clause do
    StreamData.fixed_map(%{
      guard: boolean_expression(),
      body: StreamData.list_of(body_construct(), min_length: 0, max_length: 3)
    })
  end

  defp body_construct do
    StreamData.one_of([
      StreamData.map(boolean_expression(), &%{kind: :if, boolean_operators: &1.operators}),
      StreamData.fixed_map(%{
        kind: StreamData.constant(:case),
        branches: StreamData.integer(1..3),
        clause_guard_operators:
          StreamData.list_of(operator_sequence(), min_length: 0, max_length: 3)
      }),
      StreamData.fixed_map(%{
        kind: StreamData.constant(:with),
        generators: StreamData.integer(1..3),
        else_branches: StreamData.integer(0..3),
        else_guard_operators:
          StreamData.list_of(operator_sequence(), min_length: 0, max_length: 3)
      })
    ])
  end

  defp boolean_expression do
    StreamData.map(operator_sequence(), &%{operators: &1})
  end

  defp operator_sequence do
    StreamData.list_of(StreamData.member_of(@boolean_operators), min_length: 0, max_length: 2)
  end

  defp render_valid_function(model) do
    declarations =
      if model.declaration?, do: [render_head(model.definition_kind, model)], else: []

    implementations = Enum.map(model.clauses, &render_clause(model.definition_kind, model, &1))

    render_module(model.module, declarations ++ implementations)
  end

  defp render_unmatched_declaration(model) do
    render_module(model.module, [render_head(model.definition_kind, model)])
  end

  defp render_wrong_kind_declaration(model) do
    body_model = %{
      module: model.module,
      function: model.function,
      definition_kind: model.implementation_kind,
      arity: model.arity,
      clauses: model.clauses
    }

    render_module(
      model.module,
      [render_head(model.declaration_kind, model)] ++
        Enum.map(model.clauses, &render_clause(model.implementation_kind, body_model, &1))
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
    guard = render_guard(clause.guard.operators)

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

  defp render_construct(%{
         kind: :case,
         branches: branches,
         clause_guard_operators: guard_operators
       }) do
    clauses =
      1..branches
      |> Enum.map(fn index ->
        operators = Enum.at(guard_operators, index - 1, [])
        guard = if operators == [], do: "", else: " when " <> boolean_chain(operators)

        "#{index}#{guard} -> :branch_#{index}"
      end)
      |> Enum.join("\n")

    """
    case value do
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

  defp render_with_else(0, _guard_operators), do: ""

  defp render_with_else(branches, guard_operators) do
    clauses =
      1..branches
      |> Enum.map(fn index ->
        operators = Enum.at(guard_operators, index - 1, [])
        guard = if operators == [], do: "", else: " when " <> boolean_chain(operators)

        ":error#{guard} -> :error_#{index}"
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
    %{
      module: Module.concat([model.module]),
      function: String.to_atom(model.function),
      arity: model.arity,
      line: expected_line(model),
      complexity: expected_complexity(model)
    }
  end

  defp expected_line(%{declaration?: true}), do: 3
  defp expected_line(_model), do: 2

  defp expected_complexity(model) do
    Enum.reduce(model.clauses, 0, fn clause, total ->
      total + 1 + length(clause.guard.operators) +
        Enum.reduce(clause.body, 0, &(&2 + construct_score(&1)))
    end)
  end

  defp construct_score(%{kind: :if, boolean_operators: operators}), do: 1 + length(operators)

  defp construct_score(%{
         kind: :case,
         branches: branches,
         clause_guard_operators: guard_operators
       }) do
    rendered_guard_score =
      guard_operators
      |> Enum.take(branches)
      |> Enum.reduce(0, &(&2 + length(&1)))

    branches + rendered_guard_score
  end

  defp construct_score(%{kind: :with} = construct) do
    rendered_guard_score =
      construct.else_guard_operators
      |> Enum.take(construct.else_branches)
      |> Enum.reduce(0, &(&2 + length(&1)))

    construct.generators + construct.else_branches +
      rendered_guard_score
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
