# Address Reviewer Findings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Address all 7 findings from the reviewer: normalize macro coverage keys so macros are not always scored as 0% covered (High); prevent nested `defmodule` from inflating outer function complexity (Medium); discover functions inside compile-time `if`/`unless` conditionals (Medium); fix the stale `Crap` moduledoc (Medium); add public API integration tests for newly supported complexity rules (Medium); expand the realistic fixture to cover new AST shapes (Medium); and mark the completed original plan as done (Low).

**Architecture:** Three implementation files change: `lib/crap/coverage.ex` gains key normalization for Erlang `:"MACRO-"` names; `lib/crap/complexity.ex` gains two new AST handling clauses; `lib/crap.ex` gets a doc-only update. Two test files expand: `test/crap_test.exs` gains integration tests, `test/crap/complexity_test.exs` gains fixture-based tests. The fixture at `fixtures/realistic_sample.ex` expands. One completed plan doc is annotated.

**Tech Stack:** Elixir, ExUnit, Erlang `:cover`, `Code.string_to_quoted/1`, Mix.

---

## File Structure

- Modify: `lib/crap/coverage.ex`
  - Responsibility: normalize Erlang cover's `:"MACRO-name"` function keys to the plain-atom form that `Crap.Complexity` emits.
- Modify: `lib/crap/complexity.ex`
  - Responsibility: stop counting nested `defmodule` bodies as outer-function complexity; discover functions in module-level `if`/`unless` branches.
- Modify: `lib/crap.ex`
  - Responsibility: fix stale moduledoc that incorrectly says threshold enforcement is deferred.
- Modify: `test/crap_test.exs`
  - Responsibility: integration tests covering guards, multi-clause, `with`, `try...else`, comprehensions, `receive`, and macros through `analyze_string/2`.
- Modify: `test/crap/complexity_test.exs`
  - Responsibility: fixture-based tests verifying new AST shapes are parsed correctly from a real file.
- Modify: `fixtures/realistic_sample.ex`
  - Responsibility: add representative functions for newly supported AST shapes so fixture-based tests can exercise `from_file/1`.
- Annotate: `docs/superpowers/plans/2026-05-16-improve-elixir-complexity-metric.md`
  - Responsibility: mark as complete so future agents do not re-execute it.

---

### Task 1: Normalize Macro Coverage Keys

**Files:**
- Modify: `lib/crap/coverage.ex`
- Modify: `test/crap/coverage_test.exs`

**Context:** Erlang `:cover` reports public macros as `{Module, :"MACRO-macro_name", arity + 1}`. `Crap.Complexity` reports macros as `{Module, :macro_name, arity}`. The mismatch causes all macros to score as 0% covered even when exercised by tests.

- [ ] **Step 1: Add a failing test for macro key normalization**

In `test/crap/coverage_test.exs`, add a test to the `describe "from_function_rows/1"` block:

```elixir
test "normalizes MACRO- prefixed function names to plain atom form" do
  rows = [
    {{Example, :"MACRO-debug", 2}, {10, 0}},
    {{Example, :regular, 1}, {5, 5}}
  ]

  result = Crap.Coverage.from_function_rows(rows)

  assert Map.has_key?(result, {Example, :debug, 1})
  refute Map.has_key?(result, {Example, :"MACRO-debug", 2})
  assert result[{Example, :debug, 1}] == 100.0
  assert result[{Example, :regular, 1}] == 50.0
end
```

- [ ] **Step 2: Run the targeted test and verify it fails**

Run: `mix test test/crap/coverage_test.exs --trace`

Expected: FAIL because `from_function_rows/1` currently passes `:"MACRO-"` keys through unchanged.

- [ ] **Step 3: Add normalization to `from_function_rows/1`**

In `lib/crap/coverage.ex`, replace:

```elixir
  def from_function_rows(rows) when is_list(rows) do
    Map.new(rows, fn {{module, function, arity}, {covered, not_covered}} ->
      total = covered + not_covered
      percent = if total == 0, do: 0.0, else: covered / total * 100
      {{module, function, arity}, percent}
    end)
  end
```

with:

```elixir
  def from_function_rows(rows) when is_list(rows) do
    Map.new(rows, fn {{module, function, arity}, {covered, not_covered}} ->
      total = covered + not_covered
      percent = if total == 0, do: 0.0, else: covered / total * 100
      {normalize_key(module, function, arity), percent}
    end)
  end

  defp normalize_key(module, function, arity) do
    case Atom.to_string(function) do
      "MACRO-" <> name -> {module, String.to_atom(name), arity - 1}
      _other -> {module, function, arity}
    end
  end
```

- [ ] **Step 4: Run targeted tests**

Run: `mix test test/crap/coverage_test.exs --trace`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/crap/coverage.ex test/crap/coverage_test.exs
git commit -m "Normalize MACRO- coverage keys so macros score correctly"
```

---

### Task 2: Prevent Nested Defmodule from Inflating Outer Function Complexity

**Files:**
- Modify: `lib/crap/complexity.ex`
- Modify: `test/crap/complexity_test.exs`

**Context:** `decision_count/1` falls through to the generic `{_name, _meta, args} when is_list(args)` clause for `defmodule` nodes, traversing the nested module body and counting its internal decision points against the enclosing function.

- [ ] **Step 1: Add a failing test for nested defmodule**

Add this test to the `describe "from_string/1"` block in `test/crap/complexity_test.exs`:

```elixir
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
```

- [ ] **Step 2: Run the targeted test and verify it fails**

Run: `mix test test/crap/complexity_test.exs --trace`

Expected: FAIL because `decision_count` currently traverses the nested `defmodule` body and counts the `if` inside `inner_fn` against `outer_fn`.

- [ ] **Step 3: Add a `decision_count` clause for `defmodule`**

In `lib/crap/complexity.ex`, add this clause immediately before the generic `{_name, _meta, args} when is_list(args)` catch-all clause:

```elixir
  defp decision_count({:defmodule, _meta, _args}), do: 0
```

- [ ] **Step 4: Run targeted tests**

Run: `mix test test/crap/complexity_test.exs --trace`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/crap/complexity.ex test/crap/complexity_test.exs
git commit -m "Stop counting nested defmodule body against outer function"
```

---

### Task 3: Discover Functions Inside Compile-Time Conditionals

**Files:**
- Modify: `lib/crap/complexity.ex`
- Modify: `test/crap/complexity_test.exs`

**Context:** Module-level `if`/`unless` wrapping `def` blocks is a common compile-time conditional pattern (e.g. `if Mix.env() == :dev do ... end`). The `functions/2` catch-all returns `[]` for these nodes, so any `def` inside is invisible and `from_string/1` returns `{:error, :invalid_source}` when the module contains only conditional definitions.

- [ ] **Step 1: Add a failing test for module-level conditionals**

Add this test to the `describe "from_string/1"` block in `test/crap/complexity_test.exs`:

```elixir
test "discovers functions defined inside module-level if and unless" do
  source = """
  defmodule Example do
    if true do
      def enabled, do: true
    end

    unless false do
      def also_enabled, do: true
    end
  end
  """

  assert {:ok, results} = Crap.Complexity.from_string(source)
  assert Enum.find(results, &(&1.function == :enabled))
  assert Enum.find(results, &(&1.function == :also_enabled))
end
```

- [ ] **Step 2: Run the targeted test and verify it fails**

Run: `mix test test/crap/complexity_test.exs --trace`

Expected: FAIL — the result is likely `{:error, :invalid_source}` because `functions/2` returns `[]` for `if`/`unless` nodes, triggering the empty-list guard in `from_string/1`.

- [ ] **Step 3: Add a `functions/2` clause for `if` and `unless`**

In `lib/crap/complexity.ex`, add this clause immediately before the catch-all `functions(_quoted, _module), do: []`:

```elixir
  defp functions({branch, _meta, args}, module) when branch in [:if, :unless] do
    case List.last(args) do
      branches when is_list(branches) ->
        Enum.flat_map(Keyword.values(branches), &functions(&1, module))

      _other ->
        []
    end
  end
```

- [ ] **Step 4: Run targeted tests**

Run: `mix test test/crap/complexity_test.exs --trace`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/crap/complexity.ex test/crap/complexity_test.exs
git commit -m "Discover functions inside module-level if/unless"
```

---

### Task 4: Fix Stale `Crap` Moduledoc

**Files:**
- Modify: `lib/crap.ex`

**Context:** The public `Crap` moduledoc says "this library does not enforce thresholds yet" and lists CI pass/fail as deferred. `Mix.Tasks.Crap` has enforced thresholds since the threshold sprint.

- [ ] **Step 1: Update the moduledoc**

In `lib/crap.ex`, replace:

```elixir
  @moduledoc """
  Public API for calculating CRAP scores from complexity and coverage data.

  The historical CRAP threshold of `30` is commonly used as a warning point, but
  this library does not enforce thresholds yet.

  Use `mix crap` for a report-only project scan from exported Mix/Erlang
  coverdata. Deferred work for later slices includes CI pass/fail behavior,
  package publishing, global configuration, machine-readable output, rich
  reporting, umbrella support, and broader path selection.
  """
```

with:

```elixir
  @moduledoc """
  Public API for calculating CRAP scores from complexity and coverage data.

  Use `mix crap` for a project scan from exported Mix/Erlang coverdata. The task
  enforces a maximum CRAP score threshold (default `30`) and fails with a non-zero
  exit when any function exceeds it.

  Deferred work for later slices includes package publishing, global configuration,
  machine-readable output, rich reporting, umbrella support, and broader path
  selection.
  """
```

- [ ] **Step 2: Run full tests to confirm no breakage**

Run: `mix test`

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/crap.ex
git commit -m "Fix stale Crap moduledoc: thresholds are enforced"
```

---

### Task 5: Add Public API Integration Tests for New Complexity Rules

**Files:**
- Modify: `test/crap_test.exs`

**Context:** All new complexity rules are unit-tested in `Crap.ComplexityTest` using `from_string/1`. There are no tests verifying these rules flow through `Crap.analyze_string/2` into final scored output, leaving the public API unchecked for guards, multi-clause aggregation, `with`, `try...else`, comprehensions, `receive`, and macros.

- [ ] **Step 1: Add integration tests for new complexity rules**

Add a new `describe` block in `test/crap_test.exs` after the existing `describe "analyze_file/2"` block:

```elixir
  describe "analyze_string/2 integration for new complexity rules" do
    test "scores function with guard boolean operator" do
      source = """
      defmodule Example do
        def valid?(value) when is_binary(value) and byte_size(value) > 0, do: true
      end
      """

      assert {:ok, [%{function: :valid?, complexity: 2, status: :scored}]} =
               Crap.analyze_string(source, %{})
    end

    test "scores aggregated multi-clause function" do
      source = """
      defmodule Example do
        def classify(value) when is_integer(value) and value > 0, do: :positive
        def classify(value) when is_integer(value) and value < 0, do: :negative
        def classify(_value), do: :other
      end
      """

      assert {:ok, [%{function: :classify, complexity: 5, status: :scored}]} =
               Crap.analyze_string(source, %{})
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

      assert {:ok, [%{function: :load, complexity: 5, status: :scored}]} =
               Crap.analyze_string(source, %{})
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

      assert {:ok, [%{function: :parse, complexity: 5, status: :scored}]} =
               Crap.analyze_string(source, %{})
    end

    test "scores function with comprehension generators and filters" do
      source = """
      defmodule Example do
        def active_names(users) do
          for user <- users, user.active?, user.confirmed?, do: user.name
        end
      end
      """

      assert {:ok, [%{function: :active_names, complexity: 4, status: :scored}]} =
               Crap.analyze_string(source, %{})
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

      assert {:ok, [%{function: :wait, complexity: 4, status: :scored}]} =
               Crap.analyze_string(source, %{})
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

      assert {:ok, results} = Crap.analyze_string(source, %{})
      assert Enum.find(results, &(&1.function == :debug)).complexity == 2
      assert Enum.find(results, &(&1.function == :trace)).complexity == 2
    end
  end
```

- [ ] **Step 2: Run targeted tests**

Run: `mix test test/crap_test.exs --trace`

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/crap_test.exs
git commit -m "Add public API integration tests for new complexity rules"
```

---

### Task 6: Expand Realistic Fixture and Add Fixture-Based Complexity Tests

**Files:**
- Modify: `fixtures/realistic_sample.ex`
- Modify: `test/crap/complexity_test.exs`

**Context:** The existing fixture only exercises `if`, `case`, `cond`, and a basic guard. None of the new AST shapes — multi-clause with guard, `with...else`, `try...else`, `for` with filters, `receive`, or macros — appear in the fixture. The `from_file/1` test is therefore a weak integration check.

- [ ] **Step 1: Expand the fixture**

In `fixtures/realistic_sample.ex`, add these functions before the closing `end`:

```elixir
  def fetch(key, opts) when is_atom(key) and is_list(opts) do
    timeout = Keyword.get(opts, :timeout, 5000)

    receive do
      {^key, value} -> {:ok, value}
      {:error, reason} -> {:error, reason}
    after
      timeout -> :timeout
    end
  end

  def process(items) do
    for item <- items, item.active?, item.valid? do
      item.name
    end
  end

  def load(id, source) do
    with {:ok, raw} <- source.fetch(id),
         {:ok, parsed} <- parse(raw) do
      {:ok, parsed}
    else
      :error -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defmacro assert_valid(expr) do
    if expr, do: :ok, else: raise("assertion failed")
  end
```

- [ ] **Step 2: Add a fixture-based complexity test for the new shapes**

In `test/crap/complexity_test.exs`, add this test to the `describe "from_file/1"` block:

```elixir
    test "parses new AST shapes in the realistic fixture" do
      path = Path.expand("../../fixtures/realistic_sample.ex", __DIR__)

      assert {:ok, results} = Crap.Complexity.from_file(path)

      fetch = Enum.find(results, &(&1.function == :fetch))
      assert fetch.module == Realistic.Sample
      assert fetch.arity == 2
      assert fetch.complexity == 5

      process = Enum.find(results, &(&1.function == :process))
      assert process.module == Realistic.Sample
      assert process.arity == 1
      assert process.complexity == 4

      load = Enum.find(results, &(&1.function == :load))
      assert load.module == Realistic.Sample
      assert load.arity == 2
      assert load.complexity == 5

      assert_valid = Enum.find(results, &(&1.function == :assert_valid))
      assert assert_valid.module == Realistic.Sample
      assert assert_valid.arity == 1
      assert assert_valid.complexity == 2
    end
```

Note: This test intentionally omits `line:` assertions because line numbers shift whenever the fixture changes.

- [ ] **Step 3: Run targeted tests**

Run: `mix test test/crap/complexity_test.exs --trace`

Expected: PASS. If complexity values differ, review the fixture AST against the counting rules in `Crap.Complexity` moduledoc and adjust either the fixture or the expected values to match the rules.

- [ ] **Step 4: Commit**

```bash
git add fixtures/realistic_sample.ex test/crap/complexity_test.exs
git commit -m "Expand fixture and add fixture-based tests for new AST shapes"
```

---

### Task 7: Annotate the Completed Original Plan

**Files:**
- Modify: `docs/superpowers/plans/2026-05-16-improve-elixir-complexity-metric.md`

**Context:** The original plan still has unchecked boxes and a superseded `try` snippet (Task 4 Step 2) that omits `try ... else`. Future agents could misread it as actionable instructions.

- [ ] **Step 1: Add a completion header**

In `docs/superpowers/plans/2026-05-16-improve-elixir-complexity-metric.md`, insert this block immediately after the H1 title line and before the `> **For agentic workers:**` instruction block:

```markdown
> **STATUS: COMPLETE** — All tasks in this plan were implemented and merged as of 2026-05-17. The `try` snippet in Task 4 Step 2 is superseded by `docs/superpowers/plans/2026-05-17-fix-try-else-complexity-and-test-name.md`. Do not re-execute this plan.

```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/plans/2026-05-16-improve-elixir-complexity-metric.md
git commit -m "Mark original complexity improvement plan as complete"
```

---

### Task 8: Full Regression Verification

- [ ] **Step 1: Run full test suite**

Run: `mix test`

Expected: PASS with all tests including the new ones.

- [ ] **Step 2: Run formatter check**

Run: `mix format --check-formatted`

Expected: PASS. If it fails, run `mix format` and commit the formatting changes before re-checking.

- [ ] **Step 3: Verify the Mix task still runs end-to-end**

Run:

```bash
mix test --cover --export-coverage default && mix crap
```

Expected: Prints a CRAP report table and exits 0 (or fails only when actual project functions exceed the threshold, which is expected behavior).

---

## Self-Review Notes

- Finding 1 (High — macro coverage mismatch): Task 1 normalizes `:"MACRO-name"` keys in `Crap.Coverage.from_function_rows/1` so macros match their complexity entries and are no longer forced to 0% coverage.
- Finding 2 (Medium — nested defmodule misattribution): Task 2 adds `decision_count({:defmodule, ...}) -> 0` so nested module internals do not inflate the enclosing function's complexity.
- Finding 3 (Medium — compile-time conditional discovery): Task 3 adds a `functions/2` clause for `if`/`unless` that descends into both branches, making conditional `def` blocks visible.
- Finding 4 (Medium — stale moduledoc): Task 4 replaces the two stale sentences in `Crap`'s moduledoc with accurate text reflecting current threshold enforcement.
- Finding 5 (Medium — no integration tests): Task 5 adds 7 `analyze_string/2` tests in `test/crap_test.exs`, one per new complexity rule, exercising the full pipeline.
- Finding 6 (Medium — thin fixture): Task 6 adds 4 representative functions to `fixtures/realistic_sample.ex` and a corresponding `from_file/1` test covering the new AST shapes.
- Finding 7 (Low — stale plan): Task 7 prepends a STATUS: COMPLETE banner to the 2026-05-16 plan.
- No public API shapes change. All results remain `%{module:, function:, arity:, line:, complexity:}` before scoring and unchanged downstream.
