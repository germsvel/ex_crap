# Fix Try Else Complexity and Test Name Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Address the two independent review findings from the Elixir complexity metric work: count `try ... else` branches and rename the misleading `try` control-flow test.

**Architecture:** Keep the public API unchanged. Make one minimal AST counting change inside `lib/crap/complexity.ex`, document the new rule in the module docs, and add tests in `test/crap/complexity_test.exs` that pin the intended `try` behavior.

**Tech Stack:** Elixir, ExUnit, quoted AST from `Code.string_to_quoted/1`, Mix.

---

## File Structure

- Modify: `lib/crap/complexity.ex`
  - Responsibility: parse Elixir AST and compute cyclomatic complexity per `{module, function, arity}`.
- Modify: `test/crap/complexity_test.exs`
  - Responsibility: document and verify the exact `try` complexity rules.

---

### Task 1: Count `try ... else` Clauses

**Files:**
- Modify: `test/crap/complexity_test.exs`
- Modify: `lib/crap/complexity.ex`

- [ ] **Step 1: Add a failing test for `try ... else` branches**

Add this test immediately after the existing test named `"counts try rescue catch and after as decision points"` in `test/crap/complexity_test.exs`:

```elixir
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
```

Expected count: base `1`, `try` itself `1`, two `else` clauses, one `rescue` clause.

- [ ] **Step 2: Run the targeted test and verify it fails**

Run: `mix test test/crap/complexity_test.exs --trace`

Expected: FAIL because `decision_count({:try, _meta, args})` currently counts `try`, `rescue`, and `catch`, but not `else` clauses. The new test should report complexity `3` instead of `5`.

- [ ] **Step 3: Count `try ... else` arrows**

In `lib/crap/complexity.ex`, replace:

```elixir
defp decision_count({:try, _meta, args}) do
  1 + arrow_count(keyword_value(args, :rescue)) + arrow_count(keyword_value(args, :catch)) +
    decision_count(args)
end
```

with:

```elixir
defp decision_count({:try, _meta, args}) do
  1 + arrow_count(keyword_value(args, :else)) + arrow_count(keyword_value(args, :rescue)) +
    arrow_count(keyword_value(args, :catch)) + decision_count(args)
end
```

- [ ] **Step 4: Update module docs for `try ... else`**

In `lib/crap/complexity.ex`, replace this bullet:

```elixir
* `try` adds `1`; each `rescue` and `catch` clause adds `1`.
```

with:

```elixir
* `try` adds `1`; each `else`, `rescue`, and `catch` clause adds `1`.
```

- [ ] **Step 5: Run targeted tests**

Run: `mix test test/crap/complexity_test.exs --trace`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/crap/complexity.ex test/crap/complexity_test.exs
git commit -m "Count try else clauses in complexity"
```

---

### Task 2: Rename Misleading `try` Test

**Files:**
- Modify: `test/crap/complexity_test.exs`

- [ ] **Step 1: Rename the existing `try` test**

In `test/crap/complexity_test.exs`, replace this test name:

```elixir
test "counts try rescue catch and after as decision points" do
```

with:

```elixir
test "counts try rescue and catch as decision points" do
```

Do not change the test body or expected complexity. The `after` block remains in the source fixture to document that it is intentionally not counted because it always runs.

- [ ] **Step 2: Run targeted tests**

Run: `mix test test/crap/complexity_test.exs --trace`

Expected: PASS. The renamed test should still assert complexity `5`.

- [ ] **Step 3: Commit**

```bash
git add test/crap/complexity_test.exs
git commit -m "Clarify try complexity test name"
```

---

### Task 3: Full Regression Verification

**Files:**
- Verify: `lib/crap/complexity.ex`
- Verify: `test/crap/complexity_test.exs`
- Verify: `test/**/*.exs`

- [ ] **Step 1: Run the full test suite**

Run: `mix test`

Expected: PASS.

- [ ] **Step 2: Run formatter check**

Run: `mix format --check-formatted`

Expected: PASS.

- [ ] **Step 3: Verify public scoring formula remains unchanged**

Run: `mix test test/crap_test.exs --trace`

Expected: PASS.

- [ ] **Step 4: Commit any verification-only formatting changes**

If `mix format --check-formatted` passed without changes, do not create a commit.

If `mix format` was needed to fix formatting, run:

```bash
git add lib/crap/complexity.ex test/crap/complexity_test.exs
git commit -m "Format try complexity updates"
```

---

## Self-Review Notes

- Spec coverage: Task 1 covers the algorithm finding for `try ... else`; Task 2 covers the misleading test-name finding; Task 3 covers regression checks.
- Placeholder scan: No placeholder markers or unspecified implementation steps remain.
- Type consistency: Public return shape stays `%{module:, function:, arity:, line:, complexity:}`; no public API or CRAP scoring formula changes are planned.
