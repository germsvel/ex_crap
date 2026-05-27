# C.R.A.P. Score Elixir Library — Research Sources

## The CRAP Metric: Origin & Definition

- **"Pardon My French, But This Code Is C.R.A.P." — Alberto Savoia (Artima, 2007)**
  The original blog series introducing the CRAP metric and formula.
  https://www.artima.com/weblogs/viewpost.jsp?thread=215899

- **Crap4j FAQ — "What Are Change Risk Anti Patterns?"**
  Canonical FAQ documenting the formula, threshold of 30, and the coverage-vs-complexity table.
  http://www.crap4j.org/faq.html

- **"Understanding CRAP and Cyclomatic Complexity Metrics" — OtterWise**
  Practitioner overview of the CRAP metric and its relationship to cyclomatic complexity.
  https://getotterwise.com/blog/understanding-crap-and-cyclomatic-complexity-metrics

## Academic & Related Research

- **"An Empirical Validation of Cognitive Complexity as a Measure of Source Code Understandability" — Muñoz Barón, Wyrich, Wagner (arXiv:2007.12520, ESEM '20)**
  Empirical study validating cognitive complexity as an alternative to McCabe CC; relevant to the choice of complexity metric.
  https://arxiv.org/abs/2007.12520
  https://arxiv.org/pdf/2007.12520

## Cross-Language Implementations

- **Crap4j (original Java Eclipse plug-in) — Alberto Savoia / Bob Evans**
  The original reference implementation (dormant).
  http://www.crap4j.org/faq.html

- **crap4java — Robert C. Martin ("Uncle Bob")**
  A more recent Java CLI implementation using JaCoCo coverage data.
  https://github.com/unclebob/crap4java

- **GMetrics CrapMetric — Groovy**
  CRAP metric implementation for Groovy using Cobertura XML coverage data.
  https://dx42.github.io/gmetrics/metrics/CrapMetric.html

- **Skunk — FastRuby (Ruby)**
  Ruby gem combining RubyCritic complexity with SimpleCov coverage to calculate a "SkunkScore" (CRAP-inspired).
  https://www.fastruby.io/blog/code-quality/introducing-skunk-stink-score-calculator.html
  https://github.com/fastruby/skunk/blob/main/README.md
  https://dev.to/etagwerker/introducing-skunk-combine-code-quality-and-coverage-to-calculate-a-stink-score-6f4

## Elixir/Erlang Coverage Internals

- **Erlang `:cover` module documentation (OTP 23)**
  Official docs for `cover:analyse/2,3`, data structures, and coverage levels (line, clause, function, module).
  https://www.erlang.org/docs/23/man/cover

- **Erlang `:cover` module (legacy OTP 5.2 docs)**
  Older but still useful reference for the cover module's architecture and API.
  http://erlang.org/documentation/doc-5.2/lib/tools-2.1/doc/html/cover.html

- **Erlang `:cover` chapter guide (OTP 20)**
  Tutorial-style guide to coverage analysis in Erlang/OTP.
  https://beta.erlang.org/docs/20/apps/tools/cover_chapter.html

- **`:cover` Linux man page**
  Concise reference for the cover module's API.
  https://linux.die.net/man/3/cover

## Elixir Cyclomatic Complexity (Credo Source Code)

- **Credo `CyclomaticComplexity` check — source code (master)**
  The actual implementation of Credo's cyclomatic complexity algorithm, including the `@op_complexity_map` and AST walker.
  https://github.com/rrrene/credo/blob/master/lib/credo/check/refactor/cyclomatic_complexity.ex

## Mix Task Architecture

- **`Mix.Task` behaviour documentation (Mix v1.19)**
  Official docs for implementing custom Mix tasks, callbacks, and the module naming convention.
  https://hexdocs.pm/mix/Mix.Task.html

- **"Writing Mix Tasks for Fun and Profit" — Mark Simpson (Def Method, Medium, 2017)**
  Practical guide covering exit code gotchas and CI integration patterns for Mix tasks.
  https://medium.com/defmethod-works/writing-mix-tasks-for-fun-and-profit-61dd609e7263

## Credo CI Integration & Configuration

- **Credo command-line switches documentation (v1.7)**
  Documents `--strict`, `--format`, `--mute-exit-status`, `--read-from-stdin`, and exit code bitmask behavior.
  https://hexdocs.pm/credo/cli_switches.html

- **Credo changelog (v1.7)**
  Documents the addition of SARIF output format and other CI-relevant features.
  https://hexdocs.pm/credo/changelog.html

- **Credo changelog (v1.5)**
  Documents earlier CI integration features and the plugin system.
  https://hexdocs.pm/credo/1.5.0/changelog.html

- **Credo Plus**
  Community extension for Credo with additional checks; useful reference for the plugin architecture.
  https://hexdocs.pm/credo_plus/readme.html

## CI Platform Integration

- **Code Climate Engine Specification**
  The JSON schema for Code Climate-compatible analysis engines (issue format, severity, fingerprinting).
  https://github.com/codeclimate/platform/blob/master/spec/analyzers/SPEC.md

- **codeclimate-action — GitHub Action for Code Climate**
  GitHub Action for uploading coverage and quality data to Code Climate; reference for CI workflow integration.
  https://github.com/paambaati/codeclimate-action

## Elixir Library Packaging

- **`mix hex.publish` documentation (Hex v2.2)**
  Official guide for publishing Elixir packages to Hex.pm, including `:package` metadata and `:files` list.
  https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html

- **Elixir Library Guidelines (v1.10)**
  Official Elixir core team guidelines for library design, including the prohibition on `Application.get_env` for library config.
  https://hexdocs.pm/elixir/1.10.4/library-guidelines.html
