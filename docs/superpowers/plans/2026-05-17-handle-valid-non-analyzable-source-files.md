# Handle Valid Non-Analyzable Source Files Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `mix crap` skip valid Elixir source files that contain no executable function or macro bodies, such as callback-only protocols, while preserving failures for truly invalid source and avoiding silent skips for supported executable containers.

**Architecture:** Separate parse validity from analysis result cardinality. `Crap.Complexity` should return `{:ok, []}` for valid source with no analyzable bodies, traverse supported executable containers such as `defmodule` and `defimpl`, `Crap.Scanner` should naturally continue past true no-row files, and `Mix.Tasks.Crap` should report an accurate no-analyzable-functions message before attempting to load coverage data.

**Tech Stack:** Elixir, Mix tasks, ExUnit, quoted AST from `Code.string_to_quoted/1`.

---

## File Structure

- Modify: `lib/crap/complexity.ex`
  - Responsibility: parse Elixir source and compute complexity rows for executable `def`, `defp`, `defmacro`, and `defmacrop` bodies inside supported containers such as `defmodule` and `defimpl`.
- Modify: `lib/crap/scanner.ex`
  - Responsibility: scan root `lib/**/*.ex` files and aggregate per-file complexity rows.
  - Expected implementation change: none required unless tests reveal an issue; it should work once complexity returns `{:ok, []}` for valid no-row files.
- Modify: `lib/mix/tasks/crap.ex`
  - Responsibility: orchestrate source scanning, coverage loading, report rendering, and threshold enforcement.
- Modify: `test/crap/complexity_test.exs`
  - Responsibility: verify parser/analyzer semantics for valid source, invalid source, and no-analyzable-body source.
- Modify: `test/crap/scanner_test.exs`
  - Responsibility: verify project scans skip valid no-row files and still fail on invalid files.
- Modify: `test/mix/tasks/crap_test.exs`
  - Responsibility: verify user-facing `mix crap` behavior.
- Modify: `test/crap_test.exs`
  - Responsibility: verify public `Crap.analyze_string/2` and `Crap.analyze_file/2` behavior follows the complexity semantics.
- Modify: `README.md`
  - Responsibility: document project scan behavior for callback-only/protocol files.

---

### Task 1: Change Complexity Semantics Without Skipping Supported Executable Containers

**Files:**
- Modify: `test/crap/complexity_test.exs`
- Modify: `lib/crap/complexity.ex`

- [ ] **Step 1: Add failing tests for valid source with no analyzable bodies**

Add these tests in `test/crap/complexity_test.exs` inside `describe "from_string/1"`, immediately before the existing test named `"returns an error tuple for invalid Elixir source"`:

```elixir
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
```

Also add this regression test in the same `describe "from_string/1"` block. It prevents the implementation from silently skipping supported executable containers that are not `defmodule`:

```elixir
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
```

- [ ] **Step 2: Run the targeted complexity tests and verify they fail**

Run: `mix test test/crap/complexity_test.exs --trace`

Expected: FAIL for the new no-analyzable-source tests because `Crap.Complexity.from_string/1` currently returns `{:error, :invalid_source}` when parsed source yields zero functions. The `defimpl` test should also fail because the analyzer currently does not descend into `defimpl` containers.

- [ ] **Step 3: Add `defimpl` traversal before changing zero-row semantics**

In `lib/crap/complexity.ex`, add this clause immediately after the existing `functions/2` clause for `defmodule`:

```elixir
defp functions({:defimpl, _meta, [protocol_ast, opts, [do: body]]}, current_module)
     when is_list(opts) do
  module = defimpl_module_name(protocol_ast, Keyword.fetch!(opts, :for), current_module)
  functions(body, module)
end
```

Add this helper near the existing `module_name/2` helpers:

```elixir
defp defimpl_module_name(protocol_ast, for_ast, current_module) do
  Module.concat([module_name(protocol_ast, current_module), module_name(for_ast, current_module)])
end
```

This intentionally covers ordinary `defimpl Protocol, for: Module do ... end` source. If a future `defimpl` AST shape appears that this helper cannot name, it should fail visibly rather than being silently treated as no executable code.

- [ ] **Step 4: Return `{:ok, []}` for parsed source with zero rows**

In `lib/crap/complexity.ex`, replace this code in `from_string/1`:

```elixir
{:ok, quoted} ->
  case functions(quoted, nil) do
    [] -> {:error, :invalid_source}
    functions -> {:ok, aggregate_clauses(functions)}
  end
```

with:

```elixir
{:ok, quoted} ->
  {:ok, quoted |> functions(nil) |> aggregate_clauses()}
```

- [ ] **Step 5: Update the complexity docs**

In `lib/crap/complexity.ex`, replace this doc sentence:

```elixir
Invalid or unsupported source returns `{:error, :invalid_source}`.
```

with:

```elixir
Invalid source returns `{:error, :invalid_source}`. Valid source with no
analyzable function or macro bodies returns `{:ok, []}`.
```

Also update the module-level description near the top of `lib/crap/complexity.ex` so it says supported executable containers include modules and protocol implementations:

```elixir
Parses Elixir source and returns sprint-local cyclomatic complexity results for
supported executable containers, including modules and protocol implementations.
```

- [ ] **Step 6: Run the targeted complexity tests and verify they pass**

Run: `mix test test/crap/complexity_test.exs --trace`

Expected: PASS. The existing invalid syntax test must still pass:

```elixir
assert {:error, :invalid_source} = Crap.Complexity.from_string("defmodule")
```

- [ ] **Step 7: Commit the complexity behavior change**

```bash
git add lib/crap/complexity.ex test/crap/complexity_test.exs
git commit -m "Handle valid source without analyzable functions"
```

---

### Task 2: Update Public API Semantics

**Files:**
- Modify: `test/crap_test.exs`
- Verify: `lib/crap.ex`

- [ ] **Step 1: Add `analyze_string/2` tests for valid no-row source and invalid source**

Add these tests in `test/crap_test.exs` inside `describe "analyze_string/2"`, after the existing test named `"scores functions with missing coverage as zero percent"`:

```elixir
test "returns an empty result for valid source with no analyzable functions" do
  source = """
  defprotocol Example.Protocol do
    def call(value)
  end
  """

  assert Crap.analyze_string(source, %{}) == {:ok, []}
end

test "still returns invalid_source for invalid source" do
  assert Crap.analyze_string("defmodule", %{}) == {:error, :invalid_source}
end
```

- [ ] **Step 2: Add an `analyze_file/2` test for valid no-row source**

Add this test in `test/crap_test.exs` inside `describe "analyze_file/2"`, after the existing realistic source file test:

```elixir
test "returns an empty result for a valid source file with no analyzable functions" do
  path = Path.join(System.tmp_dir!(), "crap-empty-api-#{System.unique_integer([:positive])}.ex")

  File.write!(path, """
  defprotocol Example.Protocol do
    def call(value)
  end
  """)

  try do
    assert Crap.analyze_file(path, %{}) == {:ok, []}
  after
    File.rm(path)
  end
end
```

- [ ] **Step 3: Update public API docs**

In `lib/crap.ex`, update the docs for `analyze_file/2` and `analyze_string/2` to state that valid source with no analyzable functions returns `{:ok, []}`.

For `analyze_file/2`, add this sentence after the existing sentence about `Crap.Complexity.from_file/1`:

```elixir
Valid files with no analyzable function or macro bodies return `{:ok, []}`.
```

For `analyze_string/2`, add this sentence after the coverage map description:

```elixir
Valid source with no analyzable function or macro bodies returns `{:ok, []}`.
```

- [ ] **Step 4: Run public API tests**

Run: `mix test test/crap_test.exs --trace`

Expected: PASS after Task 1. No implementation change should be needed in `lib/crap.ex` because it already passes through `Crap.Complexity` results.

- [ ] **Step 5: Commit public API coverage**

```bash
git add lib/crap.ex test/crap_test.exs
git commit -m "Document empty source analysis API behavior"
```

---

### Task 3: Lock Scanner Behavior Around Skipped Files

**Files:**
- Modify: `test/crap/scanner_test.exs`
- Verify: `lib/crap/scanner.ex`

- [ ] **Step 1: Add a scanner test for only valid no-row files**

Add this test inside `describe "analyze/1"` in `test/crap/scanner_test.exs`, after the existing test named `"returns an empty result when no root lib source files exist"`:

```elixir
test "returns an empty result when source files have no analyzable function bodies" do
  root = tmp_dir("scanner-no-analyzable-functions")

  write_source(root, "lib/driver.ex", """
  defprotocol Example.Driver do
    def visit(initial_struct, path)
  end
  """)

  assert Crap.Scanner.analyze(root) == {:ok, []}
end
```

- [ ] **Step 2: Add a scanner test for mixed skipped and analyzed files**

Add this test immediately after the previous new test:

```elixir
test "continues analyzing files after valid files with no analyzable function bodies" do
  root = tmp_dir("scanner-mixed-analyzable-functions")

  write_source(root, "lib/a_driver.ex", """
  defprotocol Example.Driver do
    def visit(initial_struct, path)
  end
  """)

  write_source(root, "lib/b_example.ex", """
  defmodule ScannerExample do
    def ok, do: :ok
  end
  """)

  assert {:ok,
          [
            %{
              file: file,
              module: ScannerExample,
              function: :ok,
              arity: 0,
              complexity: 1
            }
          ]} = Crap.Scanner.analyze(root)

  assert file == Path.join(root, "lib/b_example.ex")
end
```

- [ ] **Step 3: Add a scanner test proving invalid syntax still halts**

Add this test immediately after the mixed-file test:

```elixir
test "returns a file-specific error for invalid source" do
  root = tmp_dir("scanner-invalid-source")
  path = write_source(root, "lib/bad.ex", "defmodule")

  assert Crap.Scanner.analyze(root) == {:error, {path, :invalid_source}}
end
```

- [ ] **Step 4: Return the written path from the scanner test helper**

In `test/crap/scanner_test.exs`, replace the helper:

```elixir
defp write_source(root, relative_path, source) do
  path = Path.join(root, relative_path)
  File.mkdir_p!(Path.dirname(path))
  File.write!(path, source)
end
```

with:

```elixir
defp write_source(root, relative_path, source) do
  path = Path.join(root, relative_path)
  File.mkdir_p!(Path.dirname(path))
  File.write!(path, source)
  path
end
```

- [ ] **Step 5: Run scanner tests**

Run: `mix test test/crap/scanner_test.exs --trace`

Expected: PASS after Task 1. No implementation change should be needed in `lib/crap/scanner.ex` because it already appends zero rows and continues for `{:ok, []}`.

- [ ] **Step 6: Commit scanner regression tests**

```bash
git add test/crap/scanner_test.exs
git commit -m "Verify scanner skips valid source without functions"
```

---

### Task 4: Fix Mix Task User-Facing Behavior

**Files:**
- Modify: `test/mix/tasks/crap_test.exs`
- Modify: `lib/mix/tasks/crap.ex`

- [ ] **Step 1: Add a Mix task test for protocol-only source**

Add this test in `test/mix/tasks/crap_test.exs` inside `describe "run/1"`, immediately after the existing test named `"prints guidance when no root lib files exist"`:

```elixir
test "prints guidance when source files have no analyzable function bodies" do
  in_tmp("crap-no-analyzable-functions", fn ->
    File.mkdir_p!("lib")

    File.write!("lib/driver.ex", """
    defprotocol Example.Driver do
      def visit(initial_struct, path)
    end
    """)

    output = capture_io(fn -> Mix.Tasks.Crap.run([]) end)

    assert output =~ "No analyzable function bodies found in root lib/**/*.ex files"
    refute output =~ "No coverage data found"
    refute output =~ "invalid_source"
  end)
end
```

- [ ] **Step 2: Add a Mix task test for mixed protocol and function source without coverdata**

Add this test immediately after the previous new test:

```elixir
test "requires coverage when at least one analyzable function exists" do
  in_tmp("crap-mixed-source-no-coverage", fn ->
    File.mkdir_p!("lib")

    File.write!("lib/a_driver.ex", """
    defprotocol Example.Driver do
      def visit(initial_struct, path)
    end
    """)

    File.write!("lib/b_example.ex", """
    defmodule Example do
      def ok, do: :ok
    end
    """)

    output =
      capture_io(fn ->
        assert_raise Mix.Error, ~r/Coverage data is missing/, fn ->
          Mix.Tasks.Crap.run([])
        end
      end)

    assert output =~ "No coverage data found"
    refute output =~ "No analyzable function bodies found"
  end)
end
```

- [ ] **Step 3: Add a Mix task test for invalid source**

Add this test immediately after the previous new test:

```elixir
test "raises a source analysis error for invalid source" do
  in_tmp("crap-invalid-source", fn ->
    File.mkdir_p!("lib")
    File.write!("lib/bad.ex", "defmodule")

    assert_raise Mix.Error,
                 ~r/Unable to analyze source file lib\/bad\.ex: :invalid_source/,
                 fn ->
                   Mix.Tasks.Crap.run([])
                 end
  end)
end
```

- [ ] **Step 4: Run Mix task tests and verify the new behavior fails**

Run: `mix test test/mix/tasks/crap_test.exs --trace`

Expected: FAIL. The protocol-only source test should currently print the no-root-files message instead of the new no-analyzable-functions message. The invalid-source test should currently raise the generic `Unable to calculate CRAP report: {path, :invalid_source}` message.

- [ ] **Step 5: Check source files before analyzing functions**

In `lib/mix/tasks/crap.ex`, replace the start of `run_report/1`:

```elixir
root = File.cwd!()

with {:ok, max_score} <- max_score(opts),
     {:ok, functions} <- Crap.Scanner.analyze(root),
     :ok <- ensure_source_files(functions),
     {:ok, coverdata_path} <- coverdata_path(opts, root),
     {:ok, coverage} <- Crap.Coverage.from_coverdata(coverdata_path) do
```

with:

```elixir
root = File.cwd!()
source_files = Crap.Scanner.source_files(root)

with {:ok, max_score} <- max_score(opts),
     :ok <- ensure_source_files(source_files),
     {:ok, functions} <- Crap.Scanner.analyze(root),
     :ok <- ensure_analyzable_functions(functions),
     {:ok, coverdata_path} <- coverdata_path(opts, root),
     {:ok, coverage} <- Crap.Coverage.from_coverdata(coverdata_path) do
```

- [ ] **Step 6: Add the no-analyzable-functions branch**

In `lib/mix/tasks/crap.ex`, add this `else` branch immediately after the existing `{:no_source_files, pattern}` branch:

```elixir
{:no_analyzable_functions, pattern} ->
  Mix.shell().info("No analyzable function bodies found in root #{pattern} files.")
```

- [ ] **Step 7: Add a file-specific source analysis error branch**

In `lib/mix/tasks/crap.ex`, add this `else` branch before the catch-all `{:error, reason}` branch:

```elixir
{:error, {path, reason}} ->
  Mix.raise("Unable to analyze source file #{Path.relative_to(path, root)}: #{inspect(reason)}")
```

- [ ] **Step 8: Update the helper functions**

In `lib/mix/tasks/crap.ex`, replace:

```elixir
defp ensure_source_files([]), do: {:no_source_files, "lib/**/*.ex"}
defp ensure_source_files(_functions), do: :ok
```

with:

```elixir
defp ensure_source_files([]), do: {:no_source_files, "lib/**/*.ex"}
defp ensure_source_files(_source_files), do: :ok

defp ensure_analyzable_functions([]), do: {:no_analyzable_functions, "lib/**/*.ex"}
defp ensure_analyzable_functions(_functions), do: :ok
```

- [ ] **Step 9: Update the Mix task moduledoc**

In `lib/mix/tasks/crap.ex`, replace this paragraph:

```elixir
The task scans only root `lib/**/*.ex` files. The default maximum CRAP score is
30 (default: 30). Use `--max-score N` to override it. The task fails when any
function exceeds the threshold or has score calculation errors. Missing function
coverage is scored as 0%. Missing coverdata input is still a usage error.
```

with:

```elixir
The task scans only root `lib/**/*.ex` files and skips valid files with no
analyzable function or macro bodies, such as callback-only protocols and
behaviour modules. The default maximum CRAP score is 30 (default: 30). Use
`--max-score N` to override it. The task fails when any function exceeds the
threshold or has score calculation errors. Missing function coverage is scored
as 0%. Missing coverdata input is a usage error when analyzable functions exist.
```

- [ ] **Step 10: Run Mix task tests**

Run: `mix test test/mix/tasks/crap_test.exs --trace`

Expected: PASS.

- [ ] **Step 11: Commit Mix task behavior**

```bash
git add lib/mix/tasks/crap.ex test/mix/tasks/crap_test.exs
git commit -m "Clarify mix crap handling for non-analyzable files"
```

---

### Task 5: Update README Documentation

**Files:**
- Modify: `README.md`
- Modify: `test/mix/tasks/crap_test.exs`

- [ ] **Step 1: Add moduledoc coverage to the task metadata test**

In `test/mix/tasks/crap_test.exs`, inside the existing `"exposes mix task docs"` test, add this assertion after the existing `assert Mix.Tasks.Crap.moduledoc() =~ "lib/**/*.ex"` assertion:

```elixir
assert Mix.Tasks.Crap.moduledoc() =~ "skips valid files with no analyzable function or macro bodies"
```

- [ ] **Step 2: Update README scan behavior**

In `README.md`, replace this paragraph:

```markdown
The task scans only root project files matching `lib/**/*.ex`. It does not scan `test/`, `config/`, `priv/`, dependencies, generated files, umbrella child apps, or arbitrary caller-provided paths.
```

with:

```markdown
The task scans only root project files matching `lib/**/*.ex`. It does not scan `test/`, `config/`, `priv/`, dependencies, generated files, umbrella child apps, or arbitrary caller-provided paths. Valid files with no analyzable function or macro bodies, such as callback-only protocols and behaviour modules, are skipped because there is no executable function body to score.
```

- [ ] **Step 3: Update README coverdata wording**

In `README.md`, replace this paragraph:

```markdown
The task fails with a non-zero exit status when any scored function is above the configured threshold or any score calculation error occurs. Missing coverdata input remains a usage error because no CRAP scores can be calculated without an importable coverage file.
```

with:

```markdown
The task fails with a non-zero exit status when any scored function is above the configured threshold or any score calculation error occurs. Missing coverdata input remains a usage error when analyzable functions exist, because no CRAP scores can be calculated without an importable coverage file.
```

- [ ] **Step 4: Run documentation-adjacent tests**

Run: `mix test test/mix/tasks/crap_test.exs --trace`

Expected: PASS.

- [ ] **Step 5: Commit documentation updates**

```bash
git add README.md test/mix/tasks/crap_test.exs
git commit -m "Document skipped non-analyzable source files"
```

---

### Task 6: Full Regression Verification

**Files:**
- Verify: `lib/crap/complexity.ex`
- Verify: `lib/crap/scanner.ex`
- Verify: `lib/mix/tasks/crap.ex`
- Verify: `lib/crap.ex`
- Verify: `test/**/*.exs`
- Verify: `README.md`

- [ ] **Step 1: Run targeted test files together**

Run: `mix test test/crap/complexity_test.exs test/crap/scanner_test.exs test/crap_test.exs test/mix/tasks/crap_test.exs`

Expected: PASS.

- [ ] **Step 2: Run the full test suite**

Run: `mix test`

Expected: PASS.

- [ ] **Step 3: Run formatter check**

Run: `mix format --check-formatted`

Expected: PASS.

- [ ] **Step 4: Manually verify the original failure mode is gone**

From `/Users/germanvelasco/germsvel/phoenix_test`, run:

```bash
mix crap
```

Expected: The task does not raise `Unable to calculate CRAP report: {"/Users/germanvelasco/germsvel/phoenix_test/lib/phoenix_test/driver.ex", :invalid_source}`. If the project has analyzable functions and no persisted coverdata, it should instead show the existing coverage guidance. If the project has only valid non-analyzable source files, it should print the no-analyzable-functions message.

- [ ] **Step 5: Commit final verification if formatting changed files**

If `mix format` changed files, run:

```bash
git add .
git commit -m "Format non-analyzable source handling changes"
```

If `mix format --check-formatted` passed without changes, do not create a commit.

---

## Self-Review Notes

- Spec coverage: The plan covers the original protocol callback failure, valid callback-only modules, empty valid modules, supported `defimpl` executable containers, public API behavior, scanner continuation, invalid syntax preservation, CLI messaging, and documentation.
- Placeholder scan: No placeholder markers or unspecified implementation steps remain.
- Type consistency: The plan uses existing return shapes: `{:ok, rows}`, `{:error, :invalid_source}`, `{:error, {path, reason}}`, and Mix task no-op branches that print and return normally.
- Scope check: The plan intentionally avoids broader support for umbrella apps, custom paths, third-party coverage formats, and non-root source scanning.
