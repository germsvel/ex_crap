# Coverage

## Purpose

This section indexes sources about coverage collection and reporting. It focuses on Erlang `:cover`, Elixir Mix coverage behavior, export/aggregation workflows, and cross-language coverage references relevant to CRAP scoring.

## Key Takeaways

- Erlang `:cover` is primarily line-oriented and tracks executable lines, not comments, blanks, function heads, or non-executable patterns.
- `:cover.analyse/3` supports `coverage` and `calls` analysis at module, function, clause, and line levels.
- Coverage values use `{Cov, NotCov}` counts or call counts, with identifiers such as `{M,F,A}` for functions and `{M,N}` for lines.
- `mix test --cover` wraps Erlang coverage behavior and supports configuration through `:test_coverage`.
- Mix coverage can export `.coverdata` and aggregate partitioned test coverage through `mix test.coverage`.
- Elixir coverage has practical blind spots around literals, macro-generated compile-time code, and same-line branch distinctions.
- ExCoveralls and covertool are reporting/export layers around coverage data, especially Coveralls and Cobertura workflows.
- PHPUnit is useful prior art because it explicitly documents CRAP as a coverage metric and supports several report formats.

## Source Map

| Source | URL | Local Cache | Usefulness |
|---|---|---|---|
| Erlang `cover` docs, OTP 23 | https://www.erlang.org/docs/23/man/cover | [`../../cache/011-erlang-cover-otp23.html`](../../cache/011-erlang-cover-otp23.html) | Canonical API and data-shape reference for coverage levels and analyses. |
| Erlang `cover` legacy docs | http://erlang.org/documentation/doc-5.2/lib/tools-2.1/doc/html/cover.html | [`../../cache/012-erlang-cover-legacy.html`](../../cache/012-erlang-cover-legacy.html) | Compact confirmation of stable answer shapes and defaults. |
| Erlang `cover` chapter guide | https://beta.erlang.org/docs/20/apps/tools/cover_chapter.html | [`../../cache/013-erlang-cover-chapter.html`](../../cache/013-erlang-cover-chapter.html) | Best worked examples for module, function, clause, and line coverage outputs. |
| Erlang `cover` man page | https://www.erlang.org/doc/man/cover.html | [`../../cache/031-erlang-cover-man.html`](../../cache/031-erlang-cover-man.html) | Modern typed API and export/import semantics. |
| Erlang `cover` app docs | https://www.erlang.org/doc/apps/tools/cover.html | [`../../cache/036-erlang-cover-app.html`](../../cache/036-erlang-cover-app.html) | Current canonical app documentation, largely overlapping with the man page. |
| `Mix.Tasks.Test` docs | https://hexdocs.pm/mix/Mix.Tasks.Test.html | [`../../cache/034-mix-tasks-test.html`](../../cache/034-mix-tasks-test.html) | `--cover`, `:test_coverage`, threshold summary, export, partition behavior, custom tools. |
| `Mix.Tasks.Test.Coverage` docs | https://hexdocs.pm/mix/Mix.Tasks.Test.Coverage.html | [`../../cache/035-mix-tasks-test-coverage.html`](../../cache/035-mix-tasks-test-coverage.html) | Aggregation/export semantics and line coverage limitations. |
| ExCoveralls documentation | https://hexdocs.pm/excoveralls/ | [`../../cache/037-excoveralls.html`](../../cache/037-excoveralls.html) | Redirect shell; use repository cache for more detail. |
| covertool package | https://hex.pm/packages/covertool | [`../../cache/038-covertool.html`](../../cache/038-covertool.html) | Confirms Cobertura XML role and package metadata. |
| PHPUnit code coverage docs | https://docs.phpunit.de/en/12.5/code-coverage.html | [`../../cache/042-phpunit-code-coverage.html`](../../cache/042-phpunit-code-coverage.html) | Cross-language coverage metrics, CRAP definition, report formats, and bytecode caveats. |

## Topics

| Topic | Notes |
|---|---|
| `erlang-cover` | Primary low-level source of Elixir coverage data. |
| `coverage-data-shape` | `{Cov, NotCov}`, calls, and module/function/clause/line levels. |
| `mix-test-cover` | Elixir CLI entry point and configuration surface. |
| `coverdata-export` | Export/import/aggregate workflows for partitioned test runs. |
| `cobertura` | XML format used by adjacent tools and CI systems. |
| `coverage-limitations` | Line coverage is not branch, path, or test-quality coverage. |

## Cross-Links

- [`../crap-metric/`](../crap-metric/) explains why coverage is cubed in the CRAP formula.
- [`../complexity/`](../complexity/) explains why coverage and complexity must be interpreted together.
- [`../elixir-tooling/`](../elixir-tooling/) covers ExCoveralls, Mix tasks, and source parsing around coverage data.
- [`../ci-reporting/`](../ci-reporting/) covers coverage uploads, CI paths, and machine-readable report behavior.
