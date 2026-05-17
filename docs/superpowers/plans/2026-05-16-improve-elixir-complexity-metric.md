# Improve Elixir Complexity Metric Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `Crap.Complexity` a more trustworthy Elixir cyclomatic complexity input for CRAP scoring by covering common Elixir decision forms, guards, multi-clause functions, and macros, while keeping the canonical CRAP formula unchanged.

**Architecture:** Keep the public API unchanged: `Crap.Complexity.from_string/1`, `from_file/1`, and downstream CRAP scoring continue to return per `{module, function, arity}` rows. Improve only the AST discovery/counting rules inside `lib/crap/complexity.ex`, with tests documenting every new decision rule. Update docs so users understand that the metric is a pragmatic uncovered-complexity risk signal, not a complete code-quality measure.

**Tech Stack:** Elixir, ExUnit, quoted AST from `Code.string_to_quoted/1`, Mix.

---

## File Structure

- Modify: `lib/crap/complexity.ex`
  - Responsibility: parse Elixir AST, discover callable units, compute cyclomatic complexity per `{module, function, arity}`.
- Modify: `test/crap/complexity_test.exs`
  - Responsibility: document and verify the exact complexity rules.
- Modify: `README.md`
  - Responsibility: accurately describe the metric’s interpretation and current missing-coverage policy.
- Optional verify-only: `lib/crap.ex`, `lib/crap/report.ex`, `lib/mix/tasks/crap.ex`
  - Responsibility: confirm CRAP formula and coverage behavior continue to work without changes.

---

### Task 1: Count `&&` and `||`

**Files:**
- Modify: `test/crap/complexity_test.exs`
- Modify: `lib/crap/complexity.ex`

- [ ] **Step 1: Add a failing test for symbolic boolean operators**

Add this test after the existing test named `"counts if, unless, and boolean operators as decision points"` in `test/crap/complexity_test.exs`:

```elixir
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
```

- [ ] **Step 2: Run the targeted test and verify it fails**

Run: `mix test test/crap/complexity_test.exs --trace`

Expected: FAIL because the function currently has complexity `1` or `2`, not `3`, since `&&` and `||` are not counted.

- [ ] **Step 3: Count symbolic boolean operators**

In `lib/crap/complexity.ex`, replace:

```elixir
defp decision_count({operator, _meta, args}) when operator in [:and, :or] do
  1 + decision_count(args)
end
```

with:

```elixir
defp decision_count({operator, _meta, args}) when operator in [:and, :or, :&&, :||] do
  1 + decision_count(args)
end
```

- [ ] **Step 4: Update module docs for boolean operators**

In `lib/crap/complexity.ex`, replace this bullet:

```elixir
* Boolean `and` and `or` operators in function bodies add `1` each.
```

with:

```elixir
* Boolean `and`, `or`, `&&`, and `||` operators add `1` each.
```

- [ ] **Step 5: Run the targeted tests**

Run: `mix test test/crap/complexity_test.exs --trace`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/crap/complexity.ex test/crap/complexity_test.exs
git commit -m "Count symbolic boolean operators in complexity"
```

---

### Task 2: Count Function Guards

**Files:**
- Modify: `test/crap/complexity_test.exs`
- Modify: `lib/crap/complexity.ex`

- [ ] **Step 1: Add a failing test for guard boolean logic**

Add this test after the symbolic boolean operator test in `test/crap/complexity_test.exs`:

```elixir
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
```

- [ ] **Step 2: Run the targeted test and verify it fails**

Run: `mix test test/crap/complexity_test.exs --trace`

Expected: FAIL because guards are currently stripped in `function_name_and_arity/1` and not counted.

- [ ] **Step 3: Introduce a helper for function head parsing**

In `lib/crap/complexity.ex`, replace the function discovery clause:

```elixir
defp functions({kind, meta, [head, [do: body]]}, module) when kind in [:def, :defp] do
  {function, arity} = function_name_and_arity(head)

  [
    %{
      module: module,
      function: function,
      arity: arity,
      line: meta[:line],
      complexity: 1 + decision_count(body)
    }
  ]
end
```

with:

```elixir
defp functions({kind, meta, [head, [do: body]]}, module) when kind in [:def, :defp] do
  {function, arity, guards} = function_name_arity_and_guards(head)

  [
    %{
      module: module,
      function: function,
      arity: arity,
      line: meta[:line],
      complexity: 1 + decision_count(guards) + decision_count(body)
    }
  ]
end
```

Then replace:

```elixir
defp function_name_and_arity({:when, _meta, [head | _guards]}),
  do: function_name_and_arity(head)

defp function_name_and_arity({name, _meta, nil}) when is_atom(name), do: {name, 0}
defp function_name_and_arity({name, _meta, args}) when is_atom(name), do: {name, length(args)}
```

with:

```elixir
defp function_name_arity_and_guards({:when, _meta, [head | guards]}) do
  {name, arity, existing_guards} = function_name_arity_and_guards(head)
  {name, arity, existing_guards ++ guards}
end

defp function_name_arity_and_guards({name, _meta, nil}) when is_atom(name), do: {name, 0, []}
defp function_name_arity_and_guards({name, _meta, args}) when is_atom(name), do: {name, length(args), []}
```

- [ ] **Step 4: Update module docs for guards**

In `lib/crap/complexity.ex`, add this bullet after the boolean operator bullet:

```elixir
* Boolean operators in function guards add `1` each.
```

- [ ] **Step 5: Run targeted tests**

Run: `mix test test/crap/complexity_test.exs --trace`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/crap/complexity.ex test/crap/complexity_test.exs
git commit -m "Count guard decisions in complexity"
```

---

### Task 3: Aggregate Multi-Clause Functions by Total Clause Risk

**Files:**
- Modify: `test/crap/complexity_test.exs`
- Modify: `lib/crap/complexity.ex`

- [ ] **Step 1: Replace the existing multi-clause expectation**

In `test/crap/complexity_test.exs`, in the test named `"handles multiple functions and aggregates same name and arity clauses"`, replace the expected `:size` result:

```elixir
assert Enum.find(results, &(&1.function == :size)) == %{
         module: Example,
         function: :size,
         arity: 1,
         line: 2,
         complexity: 2
       }
```

with:

```elixir
assert Enum.find(results, &(&1.function == :size)) == %{
         module: Example,
         function: :size,
         arity: 1,
         line: 2,
         complexity: 3
       }
```

This reflects one path for each clause and one `if` decision in the second clause.

- [ ] **Step 2: Add a failing test for guard-only multi-clause branching**

Add this test after the existing multi-clause test:

```elixir
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
```

- [ ] **Step 3: Run targeted tests and verify failure**

Run: `mix test test/crap/complexity_test.exs --trace`

Expected: FAIL because `aggregate_clauses/1` currently keeps only max clause complexity.

- [ ] **Step 4: Change clause aggregation to function-level total**

In `lib/crap/complexity.ex`, replace:

```elixir
defp aggregate_clauses(functions) do
  functions
  |> Enum.group_by(&{&1.module, &1.function, &1.arity})
  |> Enum.map(fn {_key, clauses} ->
    first = Enum.min_by(clauses, &(&1.line || 0))
    max_complexity = clauses |> Enum.map(& &1.complexity) |> Enum.max()
    %{first | complexity: max_complexity}
  end)
  |> Enum.sort_by(&{inspect(&1.module), &1.line || 0, &1.function, &1.arity})
end
```

with:

```elixir
defp aggregate_clauses(functions) do
  functions
  |> Enum.group_by(&{&1.module, &1.function, &1.arity})
  |> Enum.map(fn {_key, clauses} ->
    first = Enum.min_by(clauses, &(&1.line || 0))

    complexity = clauses |> Enum.map(& &1.complexity) |> Enum.sum()

    %{first | complexity: complexity}
  end)
  |> Enum.sort_by(&{inspect(&1.module), &1.line || 0, &1.function, &1.arity})
end
```

Rationale: each clause contributes one possible path plus its guard/body decisions, while coverage remains joined at the function/arity level.

- [ ] **Step 5: Update module docs for clause aggregation**

In `lib/crap/complexity.ex`, replace:

```elixir
* Multiple clauses for the same `{module, function, arity}` are aggregated by
  keeping the maximum clause complexity and earliest line number.
```

with:

```elixir
* Multiple clauses for the same `{module, function, arity}` are aggregated by
  summing one path per clause plus each clause's guard/body decisions.
```

- [ ] **Step 6: Run targeted tests**

Run: `mix test test/crap/complexity_test.exs --trace`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/crap/complexity.ex test/crap/complexity_test.exs
git commit -m "Aggregate multi-clause complexity by function"
```

---

### Task 4: Count Additional Elixir Control Flow Forms

**Files:**
- Modify: `test/crap/complexity_test.exs`
- Modify: `lib/crap/complexity.ex`

- [ ] **Step 1: Add a failing test for `with` and `else` branches**

Add this test after the `case` / `cond` test:

```elixir
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
```

Expected count: base `1`, two `<-` generators, two `else` clauses.

- [ ] **Step 2: Add a failing test for `try` / `rescue` / `catch` / `after`**

Add this test after the `with` test:

```elixir
test "counts try rescue catch and after as decision points" do
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
```

Expected count: base `1`, `try` itself, two rescue clauses, one catch clause. Do not count `after` as a separate path because it always runs.

- [ ] **Step 3: Add a failing test for comprehensions**

Add this test after the `try` test:

```elixir
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
```

Expected count: base `1`, one generator, two filters.

- [ ] **Step 4: Add a failing test for `receive` clauses**

Add this test after the comprehension test:

```elixir
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
```

Expected count: base `1`, two receive clauses, one timeout branch.

- [ ] **Step 5: Run targeted tests and verify failures**

Run: `mix test test/crap/complexity_test.exs --trace`

Expected: FAIL because `with`, `try`, `for`, and `receive` are not yet counted.

- [ ] **Step 6: Add helpers for keyword AST access and arrow clause counting**

In `lib/crap/complexity.ex`, replace the existing `branch_count/1` helper:

```elixir
defp branch_count(args) do
  args
  |> Enum.find(&Keyword.keyword?/1)
  |> case do
    nil -> nil
    keyword -> Keyword.get(keyword, :do)
  end
  |> case do
    clauses when is_list(clauses) -> Enum.count(clauses, &match?({:->, _meta, _clause}, &1))
    {:__block__, _meta, clauses} -> Enum.count(clauses, &match?({:->, _meta, _clause}, &1))
    {:->, _meta, _clause} -> 1
    _other -> 0
  end
end
```

with:

```elixir
defp branch_count(args), do: args |> keyword_value(:do) |> arrow_count()

defp keyword_value(args, key) do
  args
  |> Enum.find(&Keyword.keyword?/1)
  |> case do
    nil -> nil
    keyword -> Keyword.get(keyword, key)
  end
end

defp arrow_count(clauses) when is_list(clauses),
  do: Enum.count(clauses, &match?({:->, _meta, _clause}, &1))

defp arrow_count({:__block__, _meta, clauses}), do: arrow_count(clauses)
defp arrow_count({:->, _meta, _clause}), do: 1
defp arrow_count(_other), do: 0
```

- [ ] **Step 7: Count `with` generators and `else` clauses**

Add these clauses above the generic `decision_count({_name, _meta, args})` clause in `lib/crap/complexity.ex`:

```elixir
defp decision_count({:with, _meta, args}) do
  generator_count(args) + arrow_count(keyword_value(args, :else)) + decision_count(args)
end

defp decision_count({:<-, _meta, args}) do
  decision_count(args)
end
```

Add this helper near `branch_count/1`:

```elixir
defp generator_count(args), do: Enum.count(args, &match?({:<-, _meta, _args}, &1))
```

- [ ] **Step 8: Count `try` rescue/catch clauses**

Add this clause above the generic `decision_count({_name, _meta, args})` clause:

```elixir
defp decision_count({:try, _meta, args}) do
  1 + arrow_count(keyword_value(args, :rescue)) + arrow_count(keyword_value(args, :catch)) +
    decision_count(args)
end
```

- [ ] **Step 9: Count comprehensions**

Add this clause above the generic `decision_count({_name, _meta, args})` clause:

```elixir
defp decision_count({:for, _meta, args}) do
  comprehension_qualifier_count(args) + decision_count(args)
end
```

Add this helper near `generator_count/1`:

```elixir
defp comprehension_qualifier_count(args) do
  Enum.count(args, fn
    {:<-, _meta, _args} -> true
    keyword when is_list(keyword) -> false
    _filter -> true
  end)
end
```

- [ ] **Step 10: Count `receive` clauses and timeout branch**

Add this clause above the generic `decision_count({_name, _meta, args})` clause:

```elixir
defp decision_count({:receive, _meta, args}) do
  branch_count(args) + receive_after_count(args) + decision_count(args)
end
```

Add this helper near `branch_count/1`:

```elixir
defp receive_after_count(args), do: if(keyword_value(args, :after), do: 1, else: 0)
```

- [ ] **Step 11: Update module docs for additional control flow**

In `lib/crap/complexity.ex`, add these bullets after the `case` / `cond` bullet:

```elixir
* Each `with` generator and `else` branch adds `1`.
* `try` adds `1`; each `rescue` and `catch` clause adds `1`.
* Each `for` generator and filter adds `1`.
* Each `receive` branch adds `1`; an `after` timeout branch adds `1`.
```

- [ ] **Step 12: Run targeted tests**

Run: `mix test test/crap/complexity_test.exs --trace`

Expected: PASS.

- [ ] **Step 13: Commit**

```bash
git add lib/crap/complexity.ex test/crap/complexity_test.exs
git commit -m "Count common Elixir control flow in complexity"
```

---

### Task 5: Discover Macros as Complexity Units

**Files:**
- Modify: `test/crap/complexity_test.exs`
- Modify: `lib/crap/complexity.ex`

- [ ] **Step 1: Add a failing test for macro discovery**

Add this test after the multi-clause tests:

```elixir
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
```

- [ ] **Step 2: Run targeted tests and verify failure**

Run: `mix test test/crap/complexity_test.exs --trace`

Expected: FAIL because only `def` and `defp` are currently discovered.

- [ ] **Step 3: Add module attributes for definition kinds**

In `lib/crap/complexity.ex`, after the `@moduledoc` block and before `@doc`, add:

```elixir
@definition_kinds [:def, :defp, :defmacro, :defmacrop]
```

Replace:

```elixir
defp functions({kind, meta, [head, [do: body]]}, module) when kind in [:def, :defp] do
```

with:

```elixir
defp functions({kind, meta, [head, [do: body]]}, module) when kind in @definition_kinds do
```

- [ ] **Step 4: Update module docs for macro discovery**

In `lib/crap/complexity.ex`, replace:

```elixir
* Each discovered `def` or `defp` starts with base complexity `1`.
```

with:

```elixir
* Each discovered `def`, `defp`, `defmacro`, or `defmacrop` starts with base complexity `1`.
```

- [ ] **Step 5: Run targeted tests**

Run: `mix test test/crap/complexity_test.exs --trace`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/crap/complexity.ex test/crap/complexity_test.exs
git commit -m "Discover macros in complexity analysis"
```

---

### Task 6: Correct README Metric Framing and Missing-Coverage Text

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update README description**

In `README.md`, replace:

```markdown
CRAP is an Elixir library and Mix task for calculating Change Risk Anti-Patterns scores from cyclomatic complexity and test coverage.
```

with:

```markdown
CRAP is an Elixir library and Mix task for calculating Change Risk Anti-Patterns scores from cyclomatic complexity and test coverage. It is a prioritization signal for uncovered complexity, not a complete code-quality or maintainability measure.
```

- [ ] **Step 2: Update stale missing-coverage behavior**

In `README.md`, replace:

```markdown
The report includes file, module, function/arity, complexity, coverage, CRAP score, and status. File paths are displayed relative to the project root. Functions with no coverage data remain visible with a `missing coverage` status and cause the task to fail because CI cannot verify their risk.

The task fails with a non-zero exit status when any scored function is above the configured threshold, any function is missing coverage, or any score calculation error occurs.
```

with:

```markdown
The report includes file, module, function/arity, complexity, coverage, CRAP score, and status. File paths are displayed relative to the project root. Functions with no matching coverage entry are scored pessimistically as `0%` covered.

The task fails with a non-zero exit status when any scored function is above the configured threshold or any score calculation error occurs. Missing coverdata input remains a usage error because no CRAP scores can be calculated without an importable coverage file.
```

- [ ] **Step 3: Add a metric limitations section**

After the Mix task section and before `## Deferred Work`, add:

```markdown
## Metric Interpretation

CRAP combines function-level cyclomatic complexity with function-level coverage to highlight code that is risky to change because it is both complex and under-tested. The default threshold of `30` follows the historical CRAP convention.

Cyclomatic complexity is only a proxy for path and test burden. It does not measure naming, cohesion, coupling, domain complexity, readability, code smells, or whether tests contain meaningful assertions. Treat high CRAP scores as a queue for investigation: add meaningful tests, simplify the function, or test before refactoring risky legacy code.
```

- [ ] **Step 4: Verify README text**

Run: `mix test`

Expected: PASS. README changes do not directly affect tests, but the full test suite should still pass.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "Document CRAP metric interpretation"
```

---

### Task 7: Full Regression and Public API Verification

**Files:**
- Verify: `lib/crap.ex`
- Verify: `lib/crap/report.ex`
- Verify: `lib/mix/tasks/crap.ex`
- Verify: `test/**/*.exs`

- [ ] **Step 1: Run the full test suite**

Run: `mix test`

Expected: PASS.

- [ ] **Step 2: Run formatter check**

Run: `mix format --check-formatted`

Expected: PASS.

- [ ] **Step 3: Verify help text still describes threshold and missing coverage correctly**

Run: `mix help crap`

Expected output includes:

```text
The task scans only root `lib/**/*.ex` files.
```

Expected output includes:

```text
Missing function coverage is scored as 0%.
```

- [ ] **Step 4: Verify public scoring formula remains unchanged**

Run: `mix test test/crap_test.exs --trace`

Expected: PASS.

- [ ] **Step 5: Commit any verification-only formatting changes**

If `mix format` modified files, run:

```bash
git add lib/crap/complexity.ex test/crap/complexity_test.exs README.md
git commit -m "Format complexity metric updates"
```

If `mix format --check-formatted` passed without changes, do not create a commit.

---

## Self-Review Notes

- Spec coverage: The plan covers all six requested improvement areas: symbolic boolean operators, guards, multi-clause aggregation, additional Elixir control flow, macros, and documentation/framing.
- Placeholder scan: No task uses placeholder markers or unspecified implementation instructions. Each code-changing step includes exact replacement or insertion content.
- Type consistency: All tasks preserve the existing public return shape: `%{module:, function:, arity:, line:, complexity:}` before scoring and existing scored row fields downstream.
