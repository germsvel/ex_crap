# Mix CRAP Threshold Enforcement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `mix crap` display project-relative paths and fail CI by default when CRAP scores exceed `30`, coverage is missing, or scoring errors occur.

**Architecture:** Keep scanning unchanged and normalize display paths in `Crap.Report.rows/3`. Add verdict helpers to `Crap.Report` so Mix task failure behavior is testable separately from CLI output. Update `Mix.Tasks.Crap` to parse `--max-score`, print the report, then raise with a clear categorized failure summary when needed.

**Tech Stack:** Elixir, Mix task APIs, ExUnit, existing `Crap.Scanner`, `Crap.Report`, and `Crap.Coverage` modules.

---

## File Structure

- Modify `lib/crap/report.ex`: add `rows/3`, relative path normalization, failure grouping, and failure summary rendering support.
- Modify `test/crap/report_test.exs`: add unit coverage for relative paths and failure grouping.
- Modify `lib/mix/tasks/crap.ex`: parse `--max-score`, update docs/metadata, pass root into report rows, and raise after report output when failures exist.
- Modify `test/mix/tasks/crap_test.exs`: update report-only expectations and add task-level threshold tests.
- Modify `README.md`: document default threshold enforcement and `--max-score`.

### Task 1: Add Report-Level Relative Paths and Failure Grouping

**Files:**
- Modify: `lib/crap/report.ex`
- Test: `test/crap/report_test.exs`

- [ ] **Step 1: Add failing tests for relative paths and failure grouping**

Add these tests to `test/crap/report_test.exs`:

```elixir
test "normalizes files relative to the provided root" do
  functions = [
    %{
      file: "/project/lib/example.ex",
      module: Example,
      function: :visible?,
      arity: 1,
      complexity: 4
    }
  ]

  coverage = %{{Example, :visible?, 1} => 75}

  assert [row] = Crap.Report.rows(functions, coverage, "/project")
  assert row.file == "lib/example.ex"
end
```

Add this describe block near the end of the file:

```elixir
describe "failures/2" do
  test "groups high scores, missing coverage, and score errors" do
    rows = [
      %{
        file: "lib/risky.ex",
        module: Example,
        function: :risky,
        arity: 0,
        complexity: 10,
        coverage_percent: 0,
        score: 110.0,
        status: :scored
      },
      %{
        file: "lib/missing.ex",
        module: Example,
        function: :missing,
        arity: 0,
        complexity: 2,
        coverage_percent: nil,
        score: nil,
        status: {:missing_coverage, {Example, :missing, 0}}
      },
      %{
        file: "lib/error.ex",
        module: Example,
        function: :bad,
        arity: 0,
        complexity: 1,
        coverage_percent: nil,
        score: nil,
        status: {:error, :invalid_coverage}
      },
      %{
        file: "lib/safe.ex",
        module: Example,
        function: :safe,
        arity: 0,
        complexity: 1,
        coverage_percent: 100,
        score: 1.0,
        status: :scored
      }
    ]

    assert %{
             high_scores: [high_score],
             missing_coverage: [missing],
             score_errors: [score_error]
           } = Crap.Report.failures(rows, 30)

    assert high_score.function == :risky
    assert missing.function == :missing
    assert score_error.function == :bad
  end

  test "does not flag scores equal to the threshold" do
    rows = [
      %{
        file: "lib/exact.ex",
        module: Example,
        function: :exact,
        arity: 0,
        complexity: 1,
        coverage_percent: 100,
        score: 30.0,
        status: :scored
      }
    ]

    assert Crap.Report.failures(rows, 30) == %{
             high_scores: [],
             missing_coverage: [],
             score_errors: []
           }
  end
end
```

- [ ] **Step 2: Run report tests to verify failure**

Run: `mix test test/crap/report_test.exs`

Expected: FAIL because `Crap.Report.rows/3` and `Crap.Report.failures/2` are undefined.

- [ ] **Step 3: Implement relative rows and failure grouping**

Update `lib/crap/report.ex` so the public functions begin like this:

```elixir
@doc """
Joins complexity results with coverage by `{module, function, arity}`.
"""
def rows(functions, coverage_by_function)
    when is_list(functions) and is_map(coverage_by_function) do
  rows(functions, coverage_by_function, nil)
end

@doc """
Joins complexity results with coverage and normalizes files relative to `root` when provided.
"""
def rows(functions, coverage_by_function, root)
    when is_list(functions) and is_map(coverage_by_function) and
           (is_binary(root) or is_nil(root)) do
  functions
  |> Enum.map(&normalize_file(&1, root))
  |> Enum.map(&row(&1, coverage_by_function))
end

@doc """
Groups rows that should fail threshold enforcement.
"""
def failures(rows, max_score) when is_list(rows) and is_number(max_score) do
  %{
    high_scores: Enum.filter(rows, &high_score?(&1, max_score)),
    missing_coverage: Enum.filter(rows, &match?({:missing_coverage, _key}, &1.status)),
    score_errors: Enum.filter(rows, &match?({:error, _reason}, &1.status))
  }
end
```

Add these private helpers below `put_score/3`:

```elixir
defp normalize_file(function, nil), do: function

defp normalize_file(function, root) do
  Map.update!(function, :file, &Path.relative_to(&1, root))
end

defp high_score?(%{score: score}, max_score) when is_number(score), do: score > max_score
defp high_score?(_row, _max_score), do: false
```

- [ ] **Step 4: Run report tests to verify pass**

Run: `mix test test/crap/report_test.exs`

Expected: PASS.

- [ ] **Step 5: Commit report changes if committing is requested**

If the user explicitly requested commits, run:

```bash
git add lib/crap/report.ex test/crap/report_test.exs
git commit -m "Add CRAP report failure grouping"
```

### Task 2: Enforce Threshold in the Mix Task

**Files:**
- Modify: `lib/mix/tasks/crap.ex`
- Test: `test/mix/tasks/crap_test.exs`

- [ ] **Step 1: Update metadata and add failing option tests**

In `test/mix/tasks/crap_test.exs`, update the metadata assertions:

```elixir
assert Mix.Tasks.Crap.shortdoc() == "Print CRAP scores for project source"
assert Mix.Tasks.Crap.moduledoc() =~ "--max-score"
assert Mix.Tasks.Crap.moduledoc() =~ "default: 30"
refute Mix.Tasks.Crap.moduledoc() =~ "report-only"
```

Add this test under `describe "run/1"`:

```elixir
test "raises for invalid max score" do
  assert_raise Mix.Error, ~r/Invalid --max-score: nope/, fn ->
    Mix.Tasks.Crap.run(["--max-score", "nope"])
  end

  assert_raise Mix.Error, ~r/Invalid --max-score: 0/, fn ->
    Mix.Tasks.Crap.run(["--max-score", "0"])
  end
end
```

- [ ] **Step 2: Run task tests to verify failure**

Run: `mix test test/mix/tasks/crap_test.exs`

Expected: FAIL because docs and option parsing still describe report-only behavior and `--max-score` is unknown.

- [ ] **Step 3: Parse and validate `--max-score`**

Update `lib/mix/tasks/crap.ex` docs and option parsing:

```elixir
@shortdoc "Print CRAP scores for project source"

@moduledoc """
Prints CRAP scores for Elixir source files and fails when results exceed the configured threshold.

Usage: mix crap

    mix test --cover --export-coverage default
    mix crap
    mix crap --coverdata path/to/file.coverdata
    mix crap --max-score 30

Coverage workflow: `mix crap` consumes persisted Mix/Erlang coverage data.
The default path is `cover/default.coverdata`, produced by
`mix test --cover --export-coverage default`. Plain `mix test --cover` prints
a coverage report, but does not leave importable coverage data for a later
`mix crap` run.

The task scans only root `lib/**/*.ex` files. The default maximum CRAP score is
30. Use `--max-score N` to override it. The task fails when any function exceeds
the threshold, has missing coverage, or has a score calculation error.
"""
```

Change `run/1` parsing to:

```elixir
case OptionParser.parse(args, strict: [coverdata: :string, max_score: :string, help: :boolean]) do
```

Add these helpers near the bottom of the module:

```elixir
defp max_score(opts) do
  case Keyword.fetch(opts, :max_score) do
    {:ok, value} -> parse_max_score(value)
    :error -> {:ok, 30.0}
  end
end

defp parse_max_score(value) do
  case Float.parse(value) do
    {score, ""} when score > 0 -> {:ok, score}
    _other -> {:error, {:invalid_max_score, value}}
  end
end
```

At the start of `run_report/1`, bind the threshold before scanning:

```elixir
with {:ok, max_score} <- max_score(opts),
     {:ok, functions} <- Crap.Scanner.analyze(root),
```

Add this `else` case before generic errors:

```elixir
{:error, {:invalid_max_score, value}} ->
  Mix.raise("Invalid --max-score: #{value}. Expected a positive number.")
```

- [ ] **Step 4: Run task tests to verify option parsing pass**

Run: `mix test test/mix/tasks/crap_test.exs`

Expected: Existing report test may still pass or fail later on enforcement, but invalid option and metadata assertions should pass.

- [ ] **Step 5: Add failing task tests for enforcement summaries**

Add these private helpers to `test/mix/tasks/crap_test.exs` before `cover_active?/0`:

```elixir
defp with_mock_report(rows, fun) do
  original_rows = :meck.new(Crap.Report, [:passthrough])
  original_scanner = :meck.new(Crap.Scanner, [:passthrough])
  original_coverage = :meck.new(Crap.Coverage, [:passthrough])

  try do
    :meck.expect(Crap.Scanner, :analyze, fn _root -> {:ok, [%{file: File.cwd!() <> "/lib/example.ex"}]} end)
    :meck.expect(Crap.Coverage, :from_coverdata, fn _path -> {:ok, %{}} end)
    :meck.expect(Crap.Report, :rows, fn _functions, _coverage, _root -> rows end)

    fun.()
  after
    :meck.unload(Crap.Report)
    :meck.unload(Crap.Scanner)
    :meck.unload(Crap.Coverage)
  end
end
```

Add `{:meck, "~> 0.9", only: :test}` to `deps` in `mix.exs` if this helper is used. If avoiding new deps, skip the helper and use direct unit tests plus one integration test with generated coverage.

Preferred no-new-dependency path: do not add this helper. Instead, add only direct task tests for invalid options and rely on `Crap.Report` unit tests for grouping. Add one integration-style test by mocking is not worth a new dependency in this small project.

- [ ] **Step 6: Implement enforcement without adding a mocking dependency**

Update the success path in `run_report/1`:

```elixir
rows = Crap.Report.rows(functions, coverage, root)
Mix.shell().info(Crap.Report.render(rows))
enforce_threshold!(rows, max_score)
```

Add these private helpers to `lib/mix/tasks/crap.ex`:

```elixir
defp enforce_threshold!(rows, max_score) do
  failures = Crap.Report.failures(rows, max_score)

  unless Enum.all?(failures, fn {_key, rows} -> rows == [] end) do
    Mix.raise(failure_message(failures, max_score))
  end
end

defp failure_message(failures, max_score) do
  [
    "CRAP threshold failed: max_score=#{format_number(max_score)}",
    failure_section("High scores", failures.high_scores, &high_score_line/1),
    failure_section("Missing coverage", failures.missing_coverage, &status_line/1),
    failure_section("Score errors", failures.score_errors, &status_line/1)
  ]
  |> Enum.reject(&(&1 == nil))
  |> Enum.join("\n")
end

defp failure_section(_title, [], _line_fun), do: nil

defp failure_section(title, rows, line_fun) do
  lines = rows |> Enum.take(5) |> Enum.map(line_fun)
  overflow = length(rows) - length(lines)
  suffix = if overflow > 0, do: ["  ... and #{overflow} more"], else: []

  (["#{title}: #{length(rows)}"] ++ lines ++ suffix)
  |> Enum.join("\n")
end

defp high_score_line(row) do
  "  #{row_identity(row)} score=#{format_number(row.score)}"
end

defp status_line(row) do
  "  #{row_identity(row)} status=#{format_status(row.status)}"
end

defp row_identity(row) do
  "#{row.file} #{inspect(row.module)}.#{row.function}/#{row.arity}"
end

defp format_status({:missing_coverage, _key}), do: "missing coverage"
defp format_status({:error, reason}), do: "error: #{reason}"
defp format_status(status), do: to_string(status)

defp format_number(number), do: :erlang.float_to_binary(number * 1.0, decimals: 2)
```

- [ ] **Step 7: Run focused task tests**

Run: `mix test test/mix/tasks/crap_test.exs`

Expected: PASS after updating expectations that no longer mention report-only behavior.

- [ ] **Step 8: Commit task changes if committing is requested**

If the user explicitly requested commits, run:

```bash
git add lib/mix/tasks/crap.ex test/mix/tasks/crap_test.exs
git commit -m "Enforce CRAP threshold in mix task"
```

### Task 3: Update Documentation and Full Verification

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update README behavior docs**

Replace the report-only section in `README.md` with:

```markdown
Then print a CRAP score table and fail if any row is unsafe:

```sh
mix crap
```

`mix crap` uses a default maximum CRAP score of `30`. Override it when needed:

```sh
mix crap --max-score 45
```

If coverage data is somewhere else, pass it explicitly:

```sh
mix crap --coverdata path/to/file.coverdata
```
```

Replace the old threshold paragraph with:

```markdown
The report includes file, module, function/arity, complexity, coverage, CRAP score, and status. File paths are displayed relative to the project root. Functions with no coverage data remain visible with a `missing coverage` status and cause the task to fail because CI cannot verify their risk.

The task fails with a non-zero exit status when any scored function is above the configured threshold, any function is missing coverage, or any score calculation error occurs.
```

Update deferred work to remove CI threshold enforcement:

```markdown
Future slices may add machine-readable formats, broader path selection, umbrella support, third-party coverage formats, and richer reporting.
```

- [ ] **Step 2: Run the full test suite**

Run: `mix test`

Expected: PASS.

- [ ] **Step 3: Run formatter check**

Run: `mix format --check-formatted`

Expected: PASS. If it fails, run `mix format`, then rerun `mix format --check-formatted`.

- [ ] **Step 4: Commit docs and verification changes if committing is requested**

If the user explicitly requested commits, run:

```bash
git add README.md
git commit -m "Document CRAP threshold enforcement"
```

## Self-Review

- Spec coverage: relative paths are covered in Task 1; default threshold and override in Task 2; missing coverage and scoring errors in Task 1 and Task 2; README docs in Task 3; full verification in Task 3.
- Placeholder scan: no TBD/TODO/implement-later placeholders remain. The plan explicitly chooses the no-new-dependency path for task-level tests.
- Type consistency: `rows/3`, `failures/2`, `max_score`, and failure category keys are used consistently across tasks.
