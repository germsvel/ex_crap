# Missing Coverage Scores As Zero Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make missing per-function coverage count as `0%` coverage for CRAP scoring, so `mix crap` fails only when a calculated CRAP score exceeds `--max-score` or scoring itself errors.

**Architecture:** Keep the existing requirement that `mix crap` needs an importable coverdata file. Change the row-building and public analysis paths so a missing coverage entry is converted to `0%` and scored normally. Remove missing coverage as an independent threshold failure category from report verdicts and Mix task failure output.

**Tech Stack:** Elixir, Mix task APIs, ExUnit, existing `Crap`, `Crap.Report`, and `Mix.Tasks.Crap` modules.

---

## File Structure

- Modify `lib/crap.ex`: update public API docs and score missing explicit coverage entries as `0%` in `analyze_string/2` and `analyze_file/2`.
- Modify `test/crap_test.exs`: update the public API missing coverage test to expect a scored `0%` row.
- Modify `lib/crap/report.ex`: treat missing report coverage entries as `0%`, keep invalid coverage as a score error, and stop grouping missing coverage as a failure.
- Modify `test/crap/report_test.exs`: update row, render, summary, and failure grouping expectations.
- Modify `lib/mix/tasks/crap.ex`: update task docs and threshold failure output so missing per-function coverage is not an independent failure reason.
- Modify `test/mix/tasks/crap_test.exs`: replace the missing coverage failure test with score-threshold behavior for missing coverage scored as `0%`.

### Task 1: Score Missing Coverage As Zero In Public API

**Files:**
- Modify: `lib/crap.ex`
- Test: `test/crap_test.exs`

- [x] **Step 1: Update the failing public API test**

In `test/crap_test.exs`, replace the test named `"marks functions with missing coverage without discovering coverage automatically"` with:

```elixir
test "scores functions with missing coverage as zero percent" do
  source = """
  defmodule Example do
    def uncovered, do: :ok
  end
  """

  assert {:ok,
          [
            %{
              module: Example,
              function: :uncovered,
              arity: 0,
              complexity: 1,
              coverage_percent: 0,
              score: 2.0,
              status: :scored
            }
          ]} = Crap.analyze_string(source, %{})
end
```

- [x] **Step 2: Run the public API test to verify failure**

Run: `mix test test/crap_test.exs`

Expected: FAIL because `Crap.analyze_string/2` still returns `status: {:missing_coverage, key}` with no score for missing coverage entries.

- [x] **Step 3: Update public API docs and missing coverage scoring**

In `lib/crap.ex`, update the `analyze_string/2` docs from:

```elixir
Coverage values are percentages from `0` to `100`. Functions without a matching
coverage entry are returned with `{:missing_coverage, key}` status. This function
does not discover or ingest coverage automatically.
```

to:

```elixir
Coverage values are percentages from `0` to `100`. Functions without a matching
coverage entry are scored as `0%` covered. This function does not discover or
ingest coverage automatically.
```

Then replace the `:error` branch in `score_function/2` with:

```elixir
:error ->
  score_function(function, Map.put(coverage_by_function, key, 0))
```

The full `score_function/2` should be:

```elixir
defp score_function(function, coverage_by_function) do
  key = {function.module, function.function, function.arity}

  case Map.fetch(coverage_by_function, key) do
    {:ok, coverage_percent} ->
      case score(function.complexity, coverage_percent) do
        {:ok, score} ->
          function
          |> Map.put(:coverage_percent, coverage_percent)
          |> Map.put(:score, score)
          |> Map.put(:status, :scored)

        {:error, reason} ->
          Map.put(function, :status, {:error, reason})
      end

    :error ->
      score_function(function, Map.put(coverage_by_function, key, 0))
  end
end
```

- [x] **Step 4: Run the public API test to verify pass**

Run: `mix test test/crap_test.exs`

Expected: PASS.

- [ ] **Step 5: Commit public API changes if committing is requested**

If the user explicitly requested commits, run:

```bash
git add lib/crap.ex test/crap_test.exs
git commit -m "Score missing coverage as zero in public API"
```

### Task 2: Score Missing Coverage As Zero In Reports

**Files:**
- Modify: `lib/crap/report.ex`
- Test: `test/crap/report_test.exs`

- [x] **Step 1: Update the missing coverage row test**

In `test/crap/report_test.exs`, replace the test named `"keeps functions with missing coverage visible"` with:

```elixir
test "scores functions with missing coverage as zero percent" do
  functions = [
    %{
      file: "/project/lib/example.ex",
      module: Example,
      function: :hidden,
      arity: 0,
      complexity: 1
    }
  ]

  assert Crap.Report.rows(functions, %{}) == [
           %{
             file: "/project/lib/example.ex",
             module: Example,
             function: :hidden,
             arity: 0,
             complexity: 1,
             coverage_percent: 0,
             score: 2.0,
             status: :scored
           }
         ]
end
```

- [x] **Step 2: Update render expectations for zero coverage**

In the `"renders sorted rows and a compact summary"` test, replace the row for `:missing` with a scored zero-coverage row:

```elixir
%{
  file: "/project/lib/c.ex",
  module: Example,
  function: :missing,
  arity: 0,
  complexity: 2,
  coverage_percent: 0,
  score: 6.0,
  status: :scored
}
```

Replace the assertion:

```elixir
assert output =~
         "/project/lib/c.ex | Example | missing/0 | 2 | missing | - | missing coverage"
```

with:

```elixir
assert output =~ "/project/lib/c.ex | Example | missing/0 | 2 | 0.00% | 6.00 | scored"
```

Replace the summary assertion with:

```elixir
assert output =~
         "Summary: files=3 functions=3 scored=3 missing_coverage=0 worst_score=20.00"
```

- [x] **Step 3: Update failure grouping expectations**

In the `"groups high scores, missing coverage, and score errors"` test, rename it to:

```elixir
test "groups high scores and score errors" do
```

Remove the `lib/missing.ex` row from the `rows` list.

Replace the assertion:

```elixir
assert %{
         high_scores: [high_score],
         missing_coverage: [missing],
         score_errors: [score_error]
       } = Crap.Report.failures(rows, 30)

assert high_score.function == :risky
assert missing.function == :missing
assert score_error.function == :bad
```

with:

```elixir
assert %{
         high_scores: [high_score],
         score_errors: [score_error]
       } = Crap.Report.failures(rows, 30)

assert high_score.function == :risky
assert score_error.function == :bad
```

In the `"does not flag scores equal to the threshold"` test, replace the expected failure map with:

```elixir
assert Crap.Report.failures(rows, 30) == %{
         high_scores: [],
         score_errors: []
       }
```

- [x] **Step 4: Run report tests to verify failure**

Run: `mix test test/crap/report_test.exs`

Expected: FAIL because `Crap.Report.rows/2` still marks missing entries as `{:missing_coverage, key}` and `Crap.Report.failures/2` still returns a `missing_coverage` category.

- [x] **Step 5: Update report scoring and failure grouping**

In `lib/crap/report.ex`, replace:

```elixir
defp put_score(row, key, :error), do: Map.put(row, :status, {:missing_coverage, key})
```

with:

```elixir
defp put_score(row, _key, :error), do: put_score(row, nil, {:ok, 0})
```

Then replace `failures/2` with:

```elixir
def failures(rows, max_score) when is_list(rows) and is_number(max_score) do
  %{
    high_scores: Enum.filter(rows, &high_score?(&1, max_score)),
    score_errors: Enum.filter(rows, &match?({:error, _reason}, &1.status))
  }
end
```

Leave `format_coverage(nil)` and `format_status({:missing_coverage, _key})` in place only if existing tests or callers still construct legacy rows directly. Do not emit `{:missing_coverage, key}` for newly built rows.

- [x] **Step 6: Run report tests to verify pass**

Run: `mix test test/crap/report_test.exs`

Expected: PASS.

- [ ] **Step 7: Commit report changes if committing is requested**

If the user explicitly requested commits, run:

```bash
git add lib/crap/report.ex test/crap/report_test.exs
git commit -m "Score missing report coverage as zero"
```

### Task 3: Make Mix Task Fail Only On Calculated Scores Or Score Errors

**Files:**
- Modify: `lib/mix/tasks/crap.ex`
- Test: `test/mix/tasks/crap_test.exs`

- [x] **Step 1: Update task metadata expectations**

In `test/mix/tasks/crap_test.exs`, replace:

```elixir
assert Mix.Tasks.Crap.moduledoc() =~ "missing coverage"
```

with:

```elixir
assert Mix.Tasks.Crap.moduledoc() =~ "missing function coverage is scored as 0%"
```

Keep this assertion unchanged:

```elixir
assert Mix.Tasks.Crap.moduledoc() =~ "score calculation error"
```

- [x] **Step 2: Replace the task-level missing coverage failure test**

In `test/mix/tasks/crap_test.exs`, replace the test named `"raises with missing coverage summary even without high scores"` with:

```elixir
test "scores missing function coverage as zero and passes when score is within threshold" do
  with_coverdata(fn coverdata_path ->
    in_tmp("crap-missing-coverage-under-threshold", fn ->
      File.mkdir_p!("lib")
      File.write!("lib/example.ex", "defmodule Example do\n  def ok, do: :ok\nend\n")

      output =
        capture_io(fn ->
          Mix.Tasks.Crap.run([
            "--coverdata",
            coverdata_path,
            "--max-score",
            "30"
          ])
        end)

      assert output =~ "lib/example.ex | Example | ok/0 | 1 | 0.00% | 2.00 | scored"
      refute output =~ "Missing coverage"
    end)
  end)
end
```

Add this test after it:

```elixir
test "fails when missing function coverage produces a score above the threshold" do
  with_coverdata(fn coverdata_path ->
    in_tmp("crap-missing-coverage-over-threshold", fn ->
      File.mkdir_p!("lib")

      File.write!(
        "lib/example.ex",
        """
        defmodule Example do
          def risky(a, b, c, d) do
            cond do
              a -> :a
              b -> :b
              c -> :c
              d -> :d
              true -> :fallback
            end
          end
        end
        """
      )

      output =
        capture_io(fn ->
          assert_raise Mix.Error,
                       ~r/CRAP threshold failed: max_score=30\.00.*High scores: 1\n  lib\/example\.ex Example\.risky\/4 score=42\.00/s,
                       fn ->
                         Mix.Tasks.Crap.run([
                           "--coverdata",
                           coverdata_path,
                           "--max-score",
                           "30"
                         ])
                       end
        end)

      assert output =~ "lib/example.ex | Example | risky/4 | 6 | 0.00% | 42.00 | scored"
      refute output =~ "Missing coverage"
    end)
  end)
end
```

- [x] **Step 3: Run task tests to verify failure**

Run: `mix test test/mix/tasks/crap_test.exs`

Expected: FAIL because task docs still describe missing coverage as an independent failure and the failure message still includes a `Missing coverage` section.

- [x] **Step 4: Update Mix task docs**

In `lib/mix/tasks/crap.ex`, replace the last sentence of `@moduledoc`:

```elixir
function exceeds the threshold, has missing coverage, or has score calculation errors.
```

with:

```elixir
function exceeds the threshold or has score calculation errors. Missing function
coverage is scored as 0%; missing coverdata input is still a usage error.
```

- [x] **Step 5: Remove missing coverage from threshold failure output**

In `lib/mix/tasks/crap.ex`, replace `failure_message/2` with:

```elixir
defp failure_message(failures, max_score) do
  [
    "CRAP threshold failed: max_score=#{format_number(max_score)}",
    failure_section("High scores", failures.high_scores, &high_score_line/1),
    failure_section("Score errors", failures.score_errors, &status_line/1)
  ]
  |> Enum.join("\n")
end
```

Remove this private function because newly built rows should no longer have missing coverage statuses:

```elixir
defp format_status({:missing_coverage, _key}), do: "missing coverage"
```

Keep these clauses:

```elixir
defp format_status({:error, reason}), do: "error: #{reason}"
defp format_status(status), do: to_string(status)
```

- [x] **Step 6: Run task tests to verify pass**

Run: `mix test test/mix/tasks/crap_test.exs`

Expected: PASS.

- [ ] **Step 7: Commit Mix task changes if committing is requested**

If the user explicitly requested commits, run:

```bash
git add lib/mix/tasks/crap.ex test/mix/tasks/crap_test.exs
git commit -m "Fail mix crap only on calculated CRAP scores"
```

### Task 4: Verify End-To-End Behavior

**Files:**
- Modify only if earlier tasks revealed formatting or test expectation issues.

- [x] **Step 1: Run the full test suite**

Run: `mix test`

Expected: PASS.

- [x] **Step 2: Run formatter check**

Run: `mix format --check-formatted`

Expected: PASS.

- [x] **Step 3: Manually inspect user-facing wording**

Run: `mix help crap`

Expected output includes:

```text
missing function coverage is scored as 0%
missing coverdata input is still a usage error
```

Expected output does not include:

```text
has missing coverage
```

- [ ] **Step 4: Commit final formatting or wording fixes if committing is requested**

If the user explicitly requested commits and any final fixes were made, run:

```bash
git add lib/crap.ex lib/crap/report.ex lib/mix/tasks/crap.ex test/crap_test.exs test/crap/report_test.exs test/mix/tasks/crap_test.exs
git commit -m "Clarify missing coverage threshold behavior"
```

## Implementation Notes

- Keep `{:error, :no_coverdata}` behavior unchanged. A missing coverdata file means the command cannot calculate CRAP and should still raise a usage/configuration error.
- Treat only missing entries inside an otherwise available coverage map as `0%` coverage.
- Keep the threshold comparison strict: a score equal to `max_score` passes; only a score greater than `max_score` fails.
- Do not add a report-only mode or new configuration in this change.

## Self-Review

- Spec coverage: The plan covers public API scoring, report row scoring, Mix task failure behavior, user-facing docs, and verification for the agreed policy.
- Placeholder scan: No `TBD`, `TODO`, or undefined follow-up steps remain.
- Type consistency: All planned row fields use existing keys: `coverage_percent`, `score`, and `status`. `Crap.Report.failures/2` consistently returns `high_scores` and `score_errors` after this change.
