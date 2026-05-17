# Handle Default-Argument Function Heads Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `mix crap` accept valid Elixir modules that declare bodyless function heads for default arguments, such as the `PhoenixTest.check/3` pattern, while still rejecting genuinely bodyless supported definitions with no implementation.

**Architecture:** Keep parse validity separate from analyzer support, but refine malformed-definition validation so a bodyless `def`/`defp`/`defmacro`/`defmacrop` is valid only when it is a declaration head for implemented clauses of the same name and arity. The analyzer should continue scoring only executable clauses with bodies; scanner and Mix task behavior should improve naturally once `Crap.Complexity.from_string/1` returns rows instead of `{:error, :invalid_source}`.

**Tech Stack:** Elixir, Mix, ExUnit, quoted AST from `Code.string_to_quoted/1`.

---

## Investigation Summary

- User-visible failure: running `mix crap` in `phoenix_test` raises `** (Mix) Unable to analyze source file lib/phoenix_test.ex: :invalid_source`.
- Subagent investigation found `lib/phoenix_test.ex` contains valid bodyless function heads used for defaults, for example `def check(session, label, opts \\ [exact: true])`, followed by implementation clauses.
- Current reproducer verified in this repo:

```elixir
source = ~S"""
defmodule Example do
  def check(session, label, opts \\ [exact: true])

  def check(session, label, opts) when is_binary(label) and is_list(opts) do
    {session, label, opts}
  end
end
"""

Crap.Complexity.from_string(source)
```

Current result: `{:error, :invalid_source}`.

Expected result: one analyzed `check/3` row.

Root-cause hypothesis: `lib/crap/complexity.ex` currently treats every bodyless supported definition inside an executable container as malformed at `malformed_executable_container?/3`, but Elixir permits bodyless heads for default arguments and predeclarations when an implementation clause exists.

---

## File Structure

- Modify: `test/crap/complexity_test.exs`
  - Responsibility: unit-level parser/analyzer semantics, including the first automated reproduction of the PhoenixTest failure shape.
- Modify: `lib/crap/complexity.ex`
  - Responsibility: distinguish invalid bodyless definitions from valid declaration heads that are backed by executable clauses.
- Modify: `test/crap/scanner_test.exs`
  - Responsibility: prove project scanning no longer converts a valid `lib/phoenix_test.ex`-shaped file into `{:error, {path, :invalid_source}}`.
- Verify: `lib/crap/scanner.ex`
  - Expected implementation change: none.
- Verify: `lib/mix/tasks/crap.ex`
  - Expected implementation change: none; existing file-specific error behavior should remain for truly invalid source.

---

### Task 1: Reproduce the PhoenixTest Failure in a Unit Test First

**Files:**
- Modify: `test/crap/complexity_test.exs`

- [ ] **Step 1: Add the failing PhoenixTest-shaped default-argument head test**

In `test/crap/complexity_test.exs`, inside `describe "from_string/1"`, add this test immediately before the existing test named `"returns an error tuple for bodyless supported definitions inside modules"`:

```elixir
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
```

- [ ] **Step 2: Run the targeted complexity test file and verify this new test fails**

Run:

```bash
mix test test/crap/complexity_test.exs --trace
```

Expected: FAIL. The new test should fail because `Crap.Complexity.from_string/1` returns `{:error, :invalid_source}` for the source above.

Do not implement any production code before this failure is observed.

- [ ] **Step 3: Commit the failing reproduction test only**

```bash
git add test/crap/complexity_test.exs
git commit -m "Reproduce default argument head analysis failure"
```

This commit is intentionally red. Do not include production code in it.

---

### Task 2: Support Valid Bodyless Declaration Heads

**Files:**
- Modify: `lib/crap/complexity.ex`
- Modify: `test/crap/complexity_test.exs`

- [ ] **Step 1: Add a regression test for non-default predeclaration heads with implementations**

In `test/crap/complexity_test.exs`, inside `describe "from_string/1"`, add this test immediately after the default-argument test from Task 1:

```elixir
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
              complexity: 3
            }
          ]} = Crap.Complexity.from_string(source)
end
```

This covers the same class of valid bodyless declaration head even when the head is not using default arguments.

- [ ] **Step 2: Run the targeted complexity test file and verify failure remains**

Run:

```bash
mix test test/crap/complexity_test.exs --trace
```

Expected: FAIL because `malformed_executable_container?/3` still treats the bodyless declaration head as invalid.

- [ ] **Step 3: Implement declaration-head-aware malformed validation**

In `lib/crap/complexity.ex`, replace the malformed-validation entry point and relevant helper clauses so validation tracks declaration heads and implemented clauses inside each executable container.

Replace:

```elixir
defp malformed_executable_container?(quoted),
  do: malformed_executable_container?(quoted, nil, false)
```

with:

```elixir
defp malformed_executable_container?(quoted),
  do: malformed_executable_container?(quoted, nil, false, MapSet.new())
```

Replace the `defmodule` malformed clause:

```elixir
defp malformed_executable_container?(
       {:defmodule, _meta, [module_ast, [do: body]]},
       current_module,
       _in_executable?
     ) do
  not module_alias?(module_ast) ||
    malformed_executable_container?(body, module_name(module_ast, current_module), true)
end
```

with:

```elixir
defp malformed_executable_container?(
       {:defmodule, _meta, [module_ast, [do: body]]},
       current_module,
       _in_executable?,
       _implemented_definitions
     ) do
  not module_alias?(module_ast) ||
    malformed_executable_container?(
      body,
      module_name(module_ast, current_module),
      true,
      implemented_definitions(body)
    )
end
```

Replace the `defimpl` malformed clause:

```elixir
defp malformed_executable_container?(
       {:defimpl, _meta, args},
       current_module,
       _in_executable?
     ) do
  case defimpl_parts(args, current_module) do
    {:ok, protocol_ast, for_ast, body} ->
      not defimpl_name_ast?(protocol_ast, for_ast) ||
        malformed_executable_container?(body, current_module, true)

    :error ->
      true
  end
end
```

with:

```elixir
defp malformed_executable_container?(
       {:defimpl, _meta, args},
       current_module,
       _in_executable?,
       _implemented_definitions
     ) do
  case defimpl_parts(args, current_module) do
    {:ok, protocol_ast, for_ast, body} ->
      not defimpl_name_ast?(protocol_ast, for_ast) ||
        malformed_executable_container?(body, current_module, true, implemented_definitions(body))

    :error ->
      true
  end
end
```

Replace the bodyless-definition malformed clause:

```elixir
defp malformed_executable_container?({kind, _meta, [_head]}, _current_module, true)
     when kind in @definition_kinds do
  true
end
```

with:

```elixir
defp malformed_executable_container?({kind, _meta, [head]}, _current_module, true, implemented_definitions)
     when kind in @definition_kinds do
  not MapSet.member?(implemented_definitions, definition_key(head))
end
```

Replace the executable definition with body malformed clause:

```elixir
defp malformed_executable_container?({kind, _meta, [_head, [do: body]]}, current_module, true)
     when kind in @definition_kinds do
  malformed_executable_container?(body, current_module, false)
end
```

with:

```elixir
defp malformed_executable_container?({kind, _meta, [_head, [do: body]]}, current_module, true, _implemented_definitions)
     when kind in @definition_kinds do
  malformed_executable_container?(body, current_module, false, MapSet.new())
end
```

Update all remaining `malformed_executable_container?/3` clauses to accept the fourth `implemented_definitions` argument and pass it through when traversing `if`, `unless`, blocks, and lists.

Add these helpers near the existing `module_alias?/1` helper:

```elixir
defp implemented_definitions(body) do
  body
  |> definitions_with_bodies()
  |> MapSet.new()
end

defp definitions_with_bodies({:__block__, _meta, expressions}) do
  Enum.flat_map(expressions, &definitions_with_bodies/1)
end

defp definitions_with_bodies({kind, _meta, [head, [do: _body]]}) when kind in @definition_kinds do
  [definition_key(head)]
end

defp definitions_with_bodies({branch, _meta, args}) when branch in [:if, :unless] do
  case List.last(args) do
    branches when is_list(branches) ->
      branches
      |> Keyword.values()
      |> Enum.flat_map(&definitions_with_bodies/1)

    _other ->
      []
  end
end

defp definitions_with_bodies(list) when is_list(list), do: Enum.flat_map(list, &definitions_with_bodies/1)
defp definitions_with_bodies(_quoted), do: []

defp definition_key({:when, _meta, [head | _guards]}), do: definition_key(head)
defp definition_key({name, _meta, nil}) when is_atom(name), do: {name, 0}
defp definition_key({name, _meta, args}) when is_atom(name), do: {name, length(args)}
```

- [ ] **Step 4: Run targeted complexity tests**

Run:

```bash
mix test test/crap/complexity_test.exs --trace
```

Expected: PASS. The existing invalid-bodyless-definition test must continue to pass:

```elixir
assert {:error, :invalid_source} = Crap.Complexity.from_string(source)
```

for source containing only `def run(arg)` with no implementation clause.

- [ ] **Step 5: Commit the complexity fix**

```bash
git add lib/crap/complexity.ex test/crap/complexity_test.exs
git commit -m "Analyze default argument function heads"
```

---

### Task 3: Add Scanner-Level Regression Coverage

**Files:**
- Modify: `test/crap/scanner_test.exs`
- Verify: `lib/crap/scanner.ex`

- [ ] **Step 1: Add a scanner test for a PhoenixTest-shaped source file**

In `test/crap/scanner_test.exs`, inside `describe "analyze/1"`, add this test immediately after the existing test named `"continues analyzing files after valid files with no analyzable function bodies"`:

```elixir
test "analyzes files with default-argument function heads" do
  root = tmp_dir("scanner-default-argument-head")
  path = write_source(root, "lib/phoenix_test.ex", ~S"""
  defmodule PhoenixTest do
    def check(session, label, opts \\ [exact: true])

    def check(session, label, opts) when is_binary(label) and is_list(opts) do
      {session, label, opts}
    end
  end
  """)

  assert {:ok,
          [
            %{
              file: ^path,
              module: PhoenixTest,
              function: :check,
              arity: 3,
              complexity: 2
            }
          ]} = Crap.Scanner.analyze(root)
end
```

- [ ] **Step 2: Run scanner tests**

Run:

```bash
mix test test/crap/scanner_test.exs --trace
```

Expected: PASS after Task 2. No implementation change should be needed in `lib/crap/scanner.ex`.

- [ ] **Step 3: Commit scanner regression coverage**

```bash
git add test/crap/scanner_test.exs
git commit -m "Verify scanner handles default argument heads"
```

---

### Task 4: Full Regression Verification

**Files:**
- Verify: `lib/crap/complexity.ex`
- Verify: `lib/crap/scanner.ex`
- Verify: `lib/mix/tasks/crap.ex`
- Verify: `test/**/*.exs`

- [ ] **Step 1: Run focused regression tests together**

Run:

```bash
mix test test/crap/complexity_test.exs test/crap/scanner_test.exs
```

Expected: PASS.

- [ ] **Step 2: Run the full test suite**

Run:

```bash
mix test
```

Expected: PASS.

- [ ] **Step 3: Run formatter check**

Run:

```bash
mix format --check-formatted
```

Expected: PASS.

- [ ] **Step 4: Do not run external phoenix_test verification**

Do not run `mix crap` in `/Users/germanvelasco/germsvel/phoenix_test`; the user will run that manually.

- [ ] **Step 5: Commit formatting only if needed**

If `mix format --check-formatted` fails, run:

```bash
mix format
mix test test/crap/complexity_test.exs test/crap/scanner_test.exs
mix test
mix format --check-formatted
git add lib/crap/complexity.ex test/crap/complexity_test.exs test/crap/scanner_test.exs
git commit -m "Format default argument head handling"
```

If `mix format --check-formatted` passes, do not create a formatting commit.

---

## Self-Review Notes

- Spec coverage: The plan starts with an automated failing unit test that reproduces the reported `phoenix_test` failure shape, then fixes root cause, adds scanner-level coverage, and runs regressions.
- Placeholder scan: No placeholder markers or unspecified implementation steps remain.
- Type consistency: The plan uses existing return shapes: `{:ok, rows}`, `{:error, :invalid_source}`, and scanner `{:error, {path, reason}}` behavior.
- Scope check: The plan does not require external `phoenix_test` execution and avoids broader compiler semantic validation beyond distinguishing valid bodyless declaration heads from invalid bodyless definitions.
