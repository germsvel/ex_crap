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

Then print a report-only CRAP score table:

```sh
mix crap
```

If coverage data is somewhere else, pass it explicitly:

```sh
mix crap --coverdata path/to/file.coverdata
```

The task scans only root project files matching `lib/**/*.ex`. It does not scan `test/`, `config/`, `priv/`, dependencies, generated files, umbrella child apps, or arbitrary caller-provided paths.

The report includes file, module, function/arity, complexity, coverage, CRAP score, and status. Functions with no coverage data remain visible with a `missing coverage` status instead of being treated as `0%` covered.

The historical CRAP threshold of `30` can help interpret scores, but this task is report-only: high scores do not fail CI and do not produce a non-zero exit status.

## Deferred Work

Future slices may add CI threshold enforcement, machine-readable formats, broader path selection, umbrella support, third-party coverage formats, and richer reporting.
