# ExCrap

ExCrap is an Elixir library and Mix task for calculating Change Risk Anti-Patterns scores from cyclomatic complexity and test coverage. It is a prioritization signal for uncovered complexity, not a complete code-quality or maintainability measure.

## Installation

Add `ex_crap` to your list of dependencies in `mix.exs`:

```elixir
{:ex_crap, "~> 0.1.0", only: [:dev, :test], runtime: false}
```

## Mix Task

The preferred way to use ExCrap is through the `mix crap` task, which scans a project from persisted Mix/Erlang coverage data and enforces a CRAP score threshold.

Generate coverage data first:

```sh
mix test --cover --export-coverage default
```

`mix crap` runs after tests and imports persisted Mix/Erlang coverage data from
`cover/default.coverdata`; plain `mix test --cover` prints a coverage report but
does not leave importable coverage data for a later `mix crap` run.

Then print compact CRAP results and fail if any row is unsafe:

```sh
mix crap
```

Pass `--verbose` to print the full scored table:

```sh
mix crap --verbose
```

`mix crap` uses a default maximum CRAP score of `30`. Override it when needed:

```sh
mix crap --max-score 45
```

If coverage data is somewhere else, pass it explicitly:

```sh
mix crap --coverdata path/to/file.coverdata
```

Scan a source directory other than `lib` when needed:

```sh
mix crap --path test/fixtures/elixir_samples
```

The task scans root project files matching `lib/**/*.ex` by default. Pass `--path PATH` to scan `PATH/**/*.ex` instead. It does not scan `test/`, `config/`, `priv/`, dependencies, generated files, or umbrella child apps unless you explicitly target one of those directories. Valid files with no analyzable function or macro bodies, such as callback-only protocols and behaviour modules, are skipped because there is no executable function body to score.

Compact output prints green checkmarks for functions at or below the configured threshold and always prints a summary. Verbose output includes file, module, function/arity, complexity, coverage, CRAP score, and status. File paths are displayed relative to the project root. Functions with no matching coverage entry are scored pessimistically as `0%` covered.

The task fails with a non-zero exit status when any scored function is above the configured threshold or any score calculation error occurs. Missing coverdata input remains a usage error when analyzable functions exist, because no CRAP scores can be calculated without an importable coverage file.

## Library API

Use the library API when you need direct score calculation or source analysis with explicit coverage data.

Calculate a score directly:

```elixir
ExCrap.score(4, 75)
# {:ok, 4.25}
```

Analyze source with explicit coverage data:

```elixir
coverage = %{{Example, :visible?, 1} => 75}
ExCrap.analyze_string(source, coverage)
```

Analyze one source file with explicit coverage data:

```elixir
coverage = %{{Example, :visible?, 1} => 75}
ExCrap.analyze_file("lib/example.ex", coverage)
```

## Metric Interpretation

CRAP combines function-level cyclomatic complexity with function-level coverage to highlight code that is risky to change because it is both complex and under-tested. The default threshold of `30` follows the historical CRAP convention.

Cyclomatic complexity is only a proxy for path and test burden. It does not measure naming, cohesion, coupling, domain complexity, readability, code smells, or whether tests contain meaningful assertions. Treat high CRAP scores as a queue for investigation: add meaningful tests, simplify the function, or test before refactoring risky legacy code.
