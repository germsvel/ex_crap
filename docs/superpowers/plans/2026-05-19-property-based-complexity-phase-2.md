# Property-Based Complexity Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand `Crap.Complexity.from_string/1` property tests from Phase 1 coverage to all analyzer-supported Elixir scoring constructs and supported executable-container shapes.

**Architecture:** Keep the property suite centered on structured source models, source rendering, and model-derived expected scores. Preserve the existing deterministic scanner and Mix task tests; Phase 2 stays focused on the analyzer because filesystem and CLI behavior are not usefully modeled by generated syntax yet. Split the expanded coverage into focused property groups so failing cases shrink to readable source instead of one broad generator producing opaque combinations.

**Tech Stack:** Elixir, ExUnit, StreamData, quoted AST parsed through `Crap.Complexity.from_string/1`.

---

## Investigation Summary

Phase 1 property tests currently cover:

- `def`, `defp`, `defmacro`, and `defmacrop` implementation clauses.
- One to three clauses aggregated by `{module, function, arity}`.
- Valid matching bodyless declaration heads.
- Invalid unmatched bodyless declaration heads and wrong-kind declaration heads.
- Function guard boolean operators: `and`, `or`, `&&`, and `||`.
- Flat body constructs: `if`, `case`, and `with`.
- Arrow-clause guards for `case` and `with else`.
- Valid non-analyzable sources: empty modules, protocol callbacks, callback-only behavior modules.

Analyzer-supported behavior still missing from property tests:

- Body scoring constructs: `unless`, `cond`, `try`, `for`, `receive`, and anonymous `fn`.
- Arrow-clause guards in `cond`, `receive`, `try rescue`, `try catch`, and anonymous `fn` clauses.
- Shallow nested body constructs that prove recursive decision counting composes across constructs.
- Executable containers and name resolution: `defimpl`, keyword-form `defimpl`, nested modules, implicit nested `defimpl for`, multiple `defimpl` targets, atom module names, `__MODULE__`, `Module.concat`, and local protocol/module alias scoping.
- Additional invalid supported-container shapes: malformed definition heads, invalid module names, invalid `defimpl` protocol/target names, unsupported top-level `defimpl` forms, and bodyless definitions inside `defimpl`.

Scanner and Mix task property tests are not recommended for Phase 2. Their behavior is integration-oriented and already covered by deterministic tests; generated filesystem/project layouts would add noise unless a specific bug appears.

---

## File Structure

- Modify: `test/crap/complexity_property_test.exs`
  - Responsibility: property-based analyzer tests, model generators, source renderers, expected-score calculation, and diagnostics.
- Verify only: `lib/crap/complexity.ex`
  - Responsibility: analyzer behavior under test. Do not change it unless a new property exposes an actual analyzer bug; if that happens, add the smallest deterministic regression test in `test/crap/complexity_test.exs` before fixing production code.
- Optional modify only if a bug is found: `test/crap/complexity_test.exs`
  - Responsibility: deterministic regression tests for any analyzer bug discovered while adding properties.

---

## Implementation Notes

- Keep helpers in `test/crap/complexity_property_test.exs` for this phase. Do not extract `test/support/complexity_case_generator.ex` unless this plan becomes unworkable during implementation.
- Keep each property at `max_runs: 50` initially.
- Prefer focused generators over one broad generator.
- Keep generated bodies shallow. Add one explicit shallow nesting property instead of making every body generator recursive.
- Expected complexity must continue to be computed from the final shrunk model at assertion time.
- Failure messages must continue including rendered source and the model.
- Do not add property-based tests for scanner or Mix task behavior in this phase.

---

### Task 1: Add `unless` and `cond` Body Construct Properties

**Files:**
- Modify: `test/crap/complexity_property_test.exs`

- [ ] **Step 1: Add failing focused properties for `unless` and `cond`**

Add these properties after the existing property named `"valid generated definitions return one row with model-derived complexity"`:

```elixir
property "valid generated definitions score unless and cond constructs" do
  check all(model <- valid_function_model(body_constructs: [:unless, :cond]), max_runs: 50) do
    source = render_valid_function(model)
    expected = expected_result(model)

    assert_analysis(source, model, {:ok, [expected]})
  end
end
```

Update `valid_function_model/0` to delegate to an arity-1 version, preserving existing callers:

```elixir
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
```

Change `clauses/0`, `clause/0`, and `body_construct/0` to accept the construct list:

```elixir
defp clauses(body_constructs) do
  StreamData.list_of(clause(body_constructs), min_length: 1, max_length: 3)
end

defp clause(body_constructs) do
  StreamData.fixed_map(%{
    guard: operator_sequence(),
    body: StreamData.list_of(body_construct(body_constructs), min_length: 1, max_length: 3)
  })
end
```

Implement `body_construct/1` as a selector over named construct generators:

```elixir
defp body_construct(kinds) do
  kinds
  |> Enum.map(&construct_generator/1)
  |> StreamData.one_of()
end
```

Move the existing `if`, `case`, and `with` generator entries into `construct_generator/1` clauses:

```elixir
defp construct_generator(:if), do: StreamData.map(operator_sequence(), &%{kind: :if, boolean_operators: &1})

defp construct_generator(:case) do
  StreamData.fixed_map(%{
    kind: StreamData.constant(:case),
    branches: StreamData.integer(1..3),
    clause_guard_operators: StreamData.list_of(operator_sequence(), min_length: 0, max_length: 3)
  })
end

defp construct_generator(:with) do
  StreamData.fixed_map(%{
    kind: StreamData.constant(:with),
    generators: StreamData.integer(1..3),
    else_branches: StreamData.integer(0..3),
    else_guard_operators: StreamData.list_of(operator_sequence(), min_length: 0, max_length: 3)
  })
end
```

- [ ] **Step 2: Run the focused property test and verify it fails**

Run:

```bash
mix test test/crap/complexity_property_test.exs --seed 0
```

Expected: FAIL with a function clause error or missing renderer/scorer for `:unless` or `:cond` models. This verifies the new property reaches unimplemented test helper paths before adding support.

- [ ] **Step 3: Add `unless` and `cond` generators**

Add these `construct_generator/1` clauses:

```elixir
defp construct_generator(:unless),
  do: StreamData.map(operator_sequence(), &%{kind: :unless, boolean_operators: &1})

defp construct_generator(:cond) do
  StreamData.fixed_map(%{
    kind: StreamData.constant(:cond),
    branches: StreamData.integer(1..3),
    clause_guard_operators: StreamData.list_of(operator_sequence(), min_length: 0, max_length: 3)
  })
end
```

- [ ] **Step 4: Add renderers for `unless` and `cond`**

Add these `render_construct/1` clauses near the existing `:if` and `:case` renderers:

```elixir
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

defp render_construct(%{kind: :cond, branches: branches, clause_guard_operators: guard_operators}) do
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
```

- [ ] **Step 5: Add expected-score rules for `unless` and `cond`**

Add these `construct_score/1` clauses:

```elixir
defp construct_score(%{kind: :unless, boolean_operators: operators}), do: 1 + length(operators)

defp construct_score(%{kind: :cond, branches: branches, clause_guard_operators: guard_operators}) do
  rendered_guard_score =
    guard_operators
    |> Enum.take(branches)
    |> Enum.reduce(0, &(&2 + length(&1)))

  branches + rendered_guard_score
end
```

- [ ] **Step 6: Run focused and full tests**

Run:

```bash
mix test test/crap/complexity_property_test.exs --seed 0
mix test
```

Expected: both PASS. Full suite should report all deterministic tests plus all properties with `0 failures`.

- [ ] **Step 7: Commit**

```bash
git add test/crap/complexity_property_test.exs
git commit -m "Cover unless and cond with property tests"
```

---

### Task 2: Add `try`, `for`, `receive`, and Anonymous `fn` Properties

**Files:**
- Modify: `test/crap/complexity_property_test.exs`

- [ ] **Step 1: Add the failing focused property**

Add this property after the `unless`/`cond` property:

```elixir
property "valid generated definitions score try for receive and anonymous function constructs" do
  check all(model <- valid_function_model(body_constructs: [:try, :for, :receive, :fn]), max_runs: 50) do
    source = render_valid_function(model)
    expected = expected_result(model)

    assert_analysis(source, model, {:ok, [expected]})
  end
end
```

- [ ] **Step 2: Run the focused property test and verify it fails**

Run:

```bash
mix test test/crap/complexity_property_test.exs --seed 0
```

Expected: FAIL with missing generator/renderer/scorer function clauses for the new construct kinds.

- [ ] **Step 3: Add generators for the remaining body constructs**

Add these `construct_generator/1` clauses:

```elixir
defp construct_generator(:try) do
  StreamData.fixed_map(%{
    kind: StreamData.constant(:try),
    else_branches: StreamData.integer(0..3),
    rescue_branches: StreamData.integer(0..3),
    rescue_guard_operators: StreamData.list_of(operator_sequence(), min_length: 0, max_length: 3),
    catch_branches: StreamData.integer(0..3),
    catch_guard_operators: StreamData.list_of(operator_sequence(), min_length: 0, max_length: 3)
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
    clause_guard_operators: StreamData.list_of(operator_sequence(), min_length: 0, max_length: 3),
    after?: StreamData.boolean()
  })
end

defp construct_generator(:fn) do
  StreamData.fixed_map(%{
    kind: StreamData.constant(:fn),
    clauses: StreamData.integer(1..3),
    clause_guard_operators: StreamData.list_of(operator_sequence(), min_length: 0, max_length: 3)
  })
end
```

- [ ] **Step 4: Add renderers for `try`, `for`, `receive`, and `fn`**

Add these `render_construct/1` clauses:

```elixir
defp render_construct(%{kind: :try} = construct) do
  """
  try do
    :ok
  #{render_try_else(construct.else_branches)}#{render_try_rescue(construct.rescue_branches, construct.rescue_guard_operators)}#{render_try_catch(construct.catch_branches, construct.catch_guard_operators)}end
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
```

Add these renderer helpers:

```elixir
defp render_try_else(0), do: ""

defp render_try_else(branches) do
  clauses = Enum.map_join(1..branches, "\n", &":ok -> :else_#{&1}")
  "else\n#{indent(clauses, 2)}\n"
end

defp render_try_rescue(0, _guard_operators), do: ""

defp render_try_rescue(branches, guard_operators) do
  clauses =
    1..branches
    |> Enum.map(fn index ->
      operators = Enum.at(guard_operators, index - 1, [])
      "error in RuntimeError#{render_guard(operators)} -> {:rescue, error, #{index}}"
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
```

- [ ] **Step 5: Add expected-score rules for the remaining body constructs**

Add these `construct_score/1` clauses:

```elixir
defp construct_score(%{kind: :try} = construct) do
  1 + construct.else_branches + construct.rescue_branches + construct.catch_branches +
    guard_score(construct.rescue_guard_operators, construct.rescue_branches) +
    guard_score(construct.catch_guard_operators, construct.catch_branches)
end

defp construct_score(%{kind: :for} = construct) do
  construct.generators + construct.filters
end

defp construct_score(%{kind: :receive} = construct) do
  after_score = if construct.after?, do: 1, else: 0
  construct.branches + after_score + guard_score(construct.clause_guard_operators, construct.branches)
end

defp construct_score(%{kind: :fn} = construct) do
  construct.clauses + guard_score(construct.clause_guard_operators, construct.clauses)
end

defp guard_score(guard_operators, rendered_clause_count) do
  guard_operators
  |> Enum.take(rendered_clause_count)
  |> Enum.reduce(0, &(&2 + length(&1)))
end
```

Then replace duplicate guard-score reductions in existing `:case`, `:cond`, and `:with` scoring with `guard_score/2`.

- [ ] **Step 6: Run focused and full tests**

Run:

```bash
mix test test/crap/complexity_property_test.exs --seed 0
mix test
```

Expected: both PASS.

- [ ] **Step 7: Commit**

```bash
git add test/crap/complexity_property_test.exs
git commit -m "Cover remaining body constructs with property tests"
```

---

### Task 3: Add Shallow Nested Body Construct Properties

**Files:**
- Modify: `test/crap/complexity_property_test.exs`

- [ ] **Step 1: Add a failing shallow-nesting property**

Add this property after the remaining-body-construct property:

```elixir
property "valid generated definitions score shallow nested body constructs" do
  check all(model <- nested_function_model(), max_runs: 50) do
    source = render_valid_function(model)
    expected = expected_result(model)

    assert_analysis(source, model, {:ok, [expected]})
  end
end
```

Add this generator:

```elixir
defp nested_function_model do
  StreamData.map(valid_function_model(body_constructs: [:nested_if_case, :nested_with_cond]), fn model ->
    %{model | clauses: Enum.take(model.clauses, 1)}
  end)
end
```

- [ ] **Step 2: Run the focused property test and verify it fails**

Run:

```bash
mix test test/crap/complexity_property_test.exs --seed 0
```

Expected: FAIL with missing generator/renderer/scorer clauses for nested construct kinds.

- [ ] **Step 3: Add nested construct generators**

Add these `construct_generator/1` clauses:

```elixir
defp construct_generator(:nested_if_case) do
  StreamData.fixed_map(%{
    kind: StreamData.constant(:nested_if_case),
    if_operators: operator_sequence(),
    case_branches: StreamData.integer(1..3),
    case_guard_operators: StreamData.list_of(operator_sequence(), min_length: 0, max_length: 3)
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
```

- [ ] **Step 4: Add nested renderers**

Add these `render_construct/1` clauses:

```elixir
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
```

- [ ] **Step 5: Add nested expected-score rules**

Add these `construct_score/1` clauses:

```elixir
defp construct_score(%{kind: :nested_if_case} = construct) do
  1 + length(construct.if_operators) + construct.case_branches +
    guard_score(construct.case_guard_operators, construct.case_branches)
end

defp construct_score(%{kind: :nested_with_cond} = construct) do
  construct.with_generators + construct.cond_branches +
    guard_score(construct.cond_guard_operators, construct.cond_branches)
end
```

- [ ] **Step 6: Run focused and full tests**

Run:

```bash
mix test test/crap/complexity_property_test.exs --seed 0
mix test
```

Expected: both PASS.

- [ ] **Step 7: Commit**

```bash
git add test/crap/complexity_property_test.exs
git commit -m "Cover shallow nested complexity constructs"
```

---

### Task 4: Add Valid `defimpl` and Multi-Target Container Properties

**Files:**
- Modify: `test/crap/complexity_property_test.exs`

- [ ] **Step 1: Add failing properties for valid `defimpl` scoring**

Add these properties after the non-analyzable-source property:

```elixir
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
```

- [ ] **Step 2: Run the focused property test and verify it fails**

Run:

```bash
mix test test/crap/complexity_property_test.exs --seed 0
```

Expected: FAIL with undefined generator/renderer/expected-result helpers.

- [ ] **Step 3: Add `defimpl` model generators**

Add these generators:

```elixir
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
```

- [ ] **Step 4: Add `defimpl` renderers**

Add these helpers:

```elixir
defp render_defimpl(%{targets: targets} = model) do
  target_source = "[#{Enum.join(targets, ", ")}]"
  render_defimpl_body(model, target_source)
end

defp render_defimpl(model) do
  render_defimpl_body(model, model.target)
end

defp render_defimpl_body(%{keyword_form?: true} = model, target_source) do
  clause = model.clauses |> List.first()

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
```

- [ ] **Step 5: Add expected `defimpl` result helpers**

Add these helpers:

```elixir
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

  %{
    module: Module.concat([Module.concat([model.protocol]), Module.concat([target])]),
    function: String.to_atom(model.function),
    arity: model.arity,
    line: 1,
    complexity: complexity
  }
end

defp clauses_complexity(clauses) do
  Enum.reduce(clauses, 0, fn clause, total ->
    total + 1 + length(clause.guard) + Enum.reduce(clause.body, 0, &(&2 + construct_score(&1)))
  end)
end
```

Then update `expected_complexity/1` to delegate to `clauses_complexity(model.clauses)`.

- [ ] **Step 6: Run focused and full tests**

Run:

```bash
mix test test/crap/complexity_property_test.exs --seed 0
mix test
```

Expected: both PASS.

- [ ] **Step 7: Commit**

```bash
git add test/crap/complexity_property_test.exs
git commit -m "Cover defimpl scoring with property tests"
```

---

### Task 5: Add Nested Module, `__MODULE__`, and `Module.concat` Container Properties

**Files:**
- Modify: `test/crap/complexity_property_test.exs`

- [ ] **Step 1: Add failing container-name properties**

Add these properties after the `defimpl` properties:

```elixir
property "valid generated nested modules resolve function result modules" do
  check all(model <- nested_module_model(), max_runs: 50) do
    source = render_nested_module(model)
    expected = expected_nested_module_result(model)

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
```

- [ ] **Step 2: Run the focused property test and verify it fails**

Run:

```bash
mix test test/crap/complexity_property_test.exs --seed 0
```

Expected: FAIL with undefined generator/renderer/expected-result helpers.

- [ ] **Step 3: Add nested module generators and renderers**

Add these helpers:

```elixir
defp nested_module_model do
  StreamData.fixed_map(%{
    outer: StreamData.constant("GeneratedOuter"),
    inner_form: StreamData.member_of([:alias, :module_alias, :module_concat]),
    function: function_name(),
    arity: StreamData.integer(0..3),
    clauses: clauses([:if, :case, :with, :unless, :cond])
  })
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

defp expected_nested_module_result(model) do
  %{
    module: GeneratedOuter.GeneratedInner,
    function: String.to_atom(model.function),
    arity: model.arity,
    line: 3,
    complexity: clauses_complexity(model.clauses)
  }
end
```

- [ ] **Step 4: Add `Module.concat` defimpl generators and renderers**

Add these helpers:

```elixir
defp module_concat_defimpl_model do
  StreamData.fixed_map(%{
    function: StreamData.constant("to_string"),
    arity: StreamData.constant(1),
    clauses: clauses([:if, :case, :with, :unless, :cond])
  })
end

defp render_module_concat_defimpl(model) do
  implementations = Enum.map(model.clauses, &render_clause(:def, model, &1))

  """
  defimpl Module.concat(String, Chars), for: Module.concat(Generated, Target) do
  #{indent(Enum.join(implementations, "\n"), 2)}
  end
  """
end

defp expected_module_concat_defimpl_result(model) do
  %{
    module: String.Chars.Generated.Target,
    function: :to_string,
    arity: 1,
    line: 2,
    complexity: clauses_complexity(model.clauses)
  }
end
```

- [ ] **Step 5: Run focused and full tests**

Run:

```bash
mix test test/crap/complexity_property_test.exs --seed 0
mix test
```

Expected: both PASS.

- [ ] **Step 6: Commit**

```bash
git add test/crap/complexity_property_test.exs
git commit -m "Cover module resolution with property tests"
```

---

### Task 6: Add Focused Invalid Supported-Container Properties

**Files:**
- Modify: `test/crap/complexity_property_test.exs`

- [ ] **Step 1: Add failing invalid-container properties**

Add these properties near the existing invalid declaration properties:

```elixir
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
```

- [ ] **Step 2: Run the focused property test and verify it fails**

Run:

```bash
mix test test/crap/complexity_property_test.exs --seed 0
```

Expected: FAIL with undefined generator/renderer helpers.

- [ ] **Step 3: Add invalid-source generators**

Add these helpers:

```elixir
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
```

- [ ] **Step 4: Add invalid-source renderers**

Add these helpers:

```elixir
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
```

- [ ] **Step 5: Run focused and full tests**

Run:

```bash
mix test test/crap/complexity_property_test.exs --seed 0
mix test
```

Expected: both PASS.

- [ ] **Step 6: Commit**

```bash
git add test/crap/complexity_property_test.exs
git commit -m "Cover invalid analyzer containers with property tests"
```

---

### Task 7: Review Property Suite Size and Keep It Maintainable

**Files:**
- Modify: `test/crap/complexity_property_test.exs`

- [ ] **Step 1: Inspect helper organization after expansion**

Open `test/crap/complexity_property_test.exs` and check these boundaries:

- Properties are grouped first.
- Generators are grouped together.
- Renderers are grouped together.
- Expected-score helpers are grouped together.
- Assertion/format helpers remain at the bottom.

- [ ] **Step 2: Refactor only local ordering and duplicate helpers**

Allowed changes:

```elixir
# Extract duplicate guard score reductions to this helper if not already done.
defp guard_score(guard_operators, rendered_clause_count) do
  guard_operators
  |> Enum.take(rendered_clause_count)
  |> Enum.reduce(0, &(&2 + length(&1)))
end
```

Do not create `test/support/complexity_case_generator.ex` in this task unless the file becomes unreadable and the reviewer explicitly requests extraction.

- [ ] **Step 3: Run format and tests**

Run:

```bash
mix format test/crap/complexity_property_test.exs
mix test test/crap/complexity_property_test.exs --seed 0
mix test
```

Expected: property file and full suite PASS.

- [ ] **Step 4: Commit if any refactor changed files**

If `git status --short` shows changes, commit them:

```bash
git add test/crap/complexity_property_test.exs
git commit -m "Organize expanded complexity property tests"
```

If there are no changes, do not create an empty commit.

---

## Completion Checklist

- [ ] `test/crap/complexity_property_test.exs` includes focused properties for every analyzer-supported body scoring construct: `if`, `unless`, `case`, `cond`, `with`, `try`, `for`, `receive`, and `fn`.
- [ ] Arrow-clause guard operator scoring is property-covered for all constructs that support arrow clauses in the analyzer.
- [ ] Shallow nested construct composition is property-covered without introducing broad recursive generators.
- [ ] Valid `defimpl` scoring is property-covered, including keyword form and multiple targets.
- [ ] Module resolution is property-covered for nested modules, `__MODULE__`, and `Module.concat` forms.
- [ ] Invalid supported-container cases are property-covered for malformed definitions and invalid `defimpl` shapes.
- [ ] Scanner and Mix task tests remain deterministic; no property tests are added for them in this phase.
- [ ] `mix test test/crap/complexity_property_test.exs --seed 0` passes.
- [ ] `mix test` passes.
