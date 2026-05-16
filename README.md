# CRAP

CRAP is an Elixir library and Mix task for calculating Change Risk Anti-Patterns scores from cyclomatic complexity and test coverage.

## Library API

Calculate a score directly:

```elixir
Crap.score(4, 75)
# {:ok, 4.25}
```

Analyze source with explicit coverage data:

```elixir
coverage = %{{Example, :visible?, 1} => 75}
Crap.analyze_string(source, coverage)
```

## Mix Task

Generate coverage data first:

```sh
mix test --cover --export-coverage default
```

`mix crap` runs after tests and imports persisted Mix/Erlang coverage data from
`cover/default.coverdata`; plain `mix test --cover` prints a coverage report but
does not leave importable coverage data for a later `mix crap` run.

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

The task scans only root project files matching `lib/**/*.ex`. It does not scan `test/`, `config/`, `priv/`, dependencies, generated files, umbrella child apps, or arbitrary caller-provided paths.

The report includes file, module, function/arity, complexity, coverage, CRAP score, and status. File paths are displayed relative to the project root. Functions with no coverage data remain visible with a `missing coverage` status and cause the task to fail because CI cannot verify their risk.

The task fails with a non-zero exit status when any scored function is above the configured threshold, any function is missing coverage, or any score calculation error occurs.

## Deferred Work

Future slices may add machine-readable formats, broader path selection, umbrella support, third-party coverage formats, and richer reporting.
