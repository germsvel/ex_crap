# Mix CRAP Threshold Enforcement Design

## Intent

Update `mix crap` so it is suitable for local and CI enforcement. The task should show project-relative file paths, enforce a default CRAP threshold of `30`, allow callers to override that threshold, and fail clearly when any function exceeds the threshold or cannot be scored because coverage is missing or invalid.

## Scope

- `mix crap` remains focused on root `lib/**/*.ex` files and persisted Mix/Erlang coverage data.
- Report output should use project-relative paths such as `lib/crap.ex`, not absolute paths.
- Threshold enforcement is on by default with a maximum score of `30`.
- `--max-score N` overrides the threshold for a run.
- The task fails after printing the report if any row is above threshold, has missing coverage, or has a score calculation error.
- Failure output should explain why the task failed with counts and representative rows for each failure category.

## Non-Goals

- No opt-out/report-only mode in this slice.
- No aggregate project CRAP score beyond the existing worst-score summary.
- No broader source path selection, umbrella support, or third-party coverage formats.

## Design

`Crap.Scanner.analyze/1` can continue attaching absolute file paths so scanning remains simple. `Crap.Report.rows/3` should accept an optional root path and normalize each row's `file` to `Path.relative_to(file, root)` before rendering or threshold evaluation. Existing `rows/2` behavior can delegate to `rows/3` with no root to keep library use straightforward.

`Crap.Report` should expose verdict logic separate from string rendering, for example `failures(rows, max_score)`. The result should group failures into high scores, missing coverage, and score errors. A row fails the threshold only when it has a numeric score greater than `max_score`; missing coverage and score errors fail independently because they prevent trustworthy CI enforcement.

`Mix.Tasks.Crap` should parse `--max-score` as a float, default to `30`, and reject invalid or non-positive values with `Mix.raise/1`. It should print the report first, then inspect the verdict. If failures exist, it should raise with a concise summary that names the threshold and includes enough row identity to act on the problem: file, module, function/arity, and score or status.

## Testing

- Report tests should verify project-relative file paths when a root is provided.
- Report tests should verify failure grouping for high scores, missing coverage, and score errors.
- Mix task tests should cover the default threshold, `--max-score` override, invalid threshold input, missing coverage failure, and clear failure text.
- Existing coverage workflow and report rendering tests should continue to pass.

## Acceptance Criteria

- Running `mix crap` with any scored row above `30` exits non-zero after printing the report and a clear threshold failure message.
- Running `mix crap --max-score N` uses `N` instead of `30`.
- Missing coverage and score errors fail the task with explicit reasons.
- Report rows display project-relative file paths.
- `mix test` passes.
