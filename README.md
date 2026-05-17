# CRAP

CRAP is an Elixir library and Mix task for calculating Change Risk Anti-Patterns scores from cyclomatic complexity and test coverage. It is a prioritization signal for uncovered complexity, not a complete code-quality or maintainability measure.

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

The task scans only root project files matching `lib/**/*.ex`. It does not scan `test/`, `config/`, `priv/`, dependencies, generated files, umbrella child apps, or arbitrary caller-provided paths. Valid files with no analyzable function or macro bodies, such as callback-only protocols and behaviour modules, are skipped because there is no executable function body to score.

The report includes file, module, function/arity, complexity, coverage, CRAP score, and status. File paths are displayed relative to the project root. Functions with no matching coverage entry are scored pessimistically as `0%` covered.

The task fails with a non-zero exit status when any scored function is above the configured threshold or any score calculation error occurs. Missing coverdata input remains a usage error when analyzable functions exist, because no CRAP scores can be calculated without an importable coverage file.

## Metric Interpretation

CRAP combines function-level cyclomatic complexity with function-level coverage to highlight code that is risky to change because it is both complex and under-tested. The default threshold of `30` follows the historical CRAP convention.

Cyclomatic complexity is only a proxy for path and test burden. It does not measure naming, cohesion, coupling, domain complexity, readability, code smells, or whether tests contain meaningful assertions. Treat high CRAP scores as a queue for investigation: add meaningful tests, simplify the function, or test before refactoring risky legacy code.

## Deferred Work

Future slices may add machine-readable formats, broader path selection, umbrella support, third-party coverage formats, and richer reporting.
