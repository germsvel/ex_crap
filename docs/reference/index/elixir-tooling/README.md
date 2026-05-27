# Elixir Tooling

## Purpose

This section indexes sources for building an Elixir-native CRAP tool: Mix task conventions, CLI behavior, AST/source parsing, Credo-style static analysis, package constraints, and adjacent tooling patterns.

## Key Takeaways

- Mix tasks are the natural CLI surface: define `Mix.Tasks.*`, `use Mix.Task`, implement `run/1`, and document with `@shortdoc` and `@moduledoc`.
- CLI tools should explicitly manage exit behavior; returning `:error` from `run/1` is not enough for a non-zero shell status.
- Credo is the strongest Elixir model for static-analysis UX: commands, filters, formats, stdin support, diff/watch workflows, and configurable exit statuses.
- Credo's cyclomatic complexity check is an implementation model for traversing function/macro AST, computing complexity, comparing against thresholds, and emitting metadata-rich issues.
- Use `Code.string_to_quoted*` for basic parsing; use Sourceror when comments, source ranges, patches, codemods, or source-preserving rendering matter.
- Elixir library design guidance favors explicit options, small public APIs, tuple-returning functions where callers need control, limited global config, minimal macros, and no unnecessary processes.
- Adjacent tools show reusable patterns: ExCoveralls for coverage tasks, Sobelow for analyzer UX, and Credo Plus for plugin/report-card ideas.

## Source Map

| Source | URL | Local Cache | Usefulness |
|---|---|---|---|
| Credo cyclomatic complexity source | https://github.com/rrrene/credo/blob/master/lib/credo/check/refactor/cyclomatic_complexity.ex | [`../../cache/015-credo-cyclomatic-source.html`](../../cache/015-credo-cyclomatic-source.html) | Implementation reference for AST traversal and complexity scoring. |
| `Mix.Task` docs | https://hexdocs.pm/mix/Mix.Task.html | [`../../cache/016-mix-task.html`](../../cache/016-mix-task.html) | Official task behavior, naming, docs, requirements, recursion, and CLI execution model. |
| "Writing Mix Tasks for Fun and Profit" | https://medium.com/defmethod-works/writing-mix-tasks-for-fun-and-profit-61dd609e7263 | [`../../cache/017-medium-writing-mix-tasks.md`](../../cache/017-medium-writing-mix-tasks.md) | Practical Mix task notes, especially shell exit behavior. |
| Credo CLI switches | https://hexdocs.pm/credo/cli_switches.html | [`../../cache/018-credo-cli-switches.html`](../../cache/018-credo-cli-switches.html) | Commands, switches, formats, stdin, include/exclude behavior, filters, watch mode, and diff mode. |
| Credo changelog | https://hexdocs.pm/credo/changelog.html | [`../../cache/019-credo-changelog.html`](../../cache/019-credo-changelog.html) | Evolution of output formats and CI-relevant behavior. |
| Credo v1.5 changelog | https://hexdocs.pm/credo/1.5.0/changelog.html | [`../../cache/020-credo-1-5-changelog.html`](../../cache/020-credo-1-5-changelog.html) | Earlier CI/plugin context and feature evolution. |
| Credo Plus README | https://hexdocs.pm/credo_plus/readme.html | [`../../cache/021-credo-plus-readme.html`](../../cache/021-credo-plus-readme.html) | Historical extension/plugin ideas around commands, reports, coverage, and config. |
| Hex publish docs | https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html | [`../../cache/024-hex-publish.html`](../../cache/024-hex-publish.html) | Publishing, docs, dry-run, package metadata, and package size constraints. |
| Elixir library guidelines | https://hexdocs.pm/elixir/1.10.4/library-guidelines.html | [`../../cache/025-elixir-library-guidelines.html`](../../cache/025-elixir-library-guidelines.html) | Library API and configuration guidance. |
| Credo repository | https://github.com/rrrene/credo | [`../../cache/028-credo-repository.html`](../../cache/028-credo-repository.html) | Repository context for Credo as the main Elixir static-analysis precedent. |
| ExCoveralls repository | https://github.com/parroty/excoveralls | [`../../cache/029-excoveralls-repository.html`](../../cache/029-excoveralls-repository.html) | Coverage tooling patterns and Mix task examples. |
| Sobelow repository | https://github.com/sobelow/sobelow | [`../../cache/030-sobelow-repository.html`](../../cache/030-sobelow-repository.html) | Analyzer UX, confidence levels, skips, config, and output formats. |
| Elixir `Code` docs | https://hexdocs.pm/elixir/Code.html | [`../../cache/032-elixir-code.html`](../../cache/032-elixir-code.html) | Parsing, formatting, quoted AST, comments, token metadata, and formatter helpers. |
| Credo cyclomatic complexity docs | https://hexdocs.pm/credo/Credo.Check.Refactor.CyclomaticComplexity.html | [`../../cache/039-credo-cyclomatic-docs.html`](../../cache/039-credo-cyclomatic-docs.html) | User-facing complexity check docs and default threshold. |
| Credo exit statuses | https://hexdocs.pm/credo/exit_statuses.html | [`../../cache/040-credo-exit-statuses.html`](../../cache/040-credo-exit-statuses.html) | Shell status model for issue categories and runtime/config errors. |
| Sourceror docs | https://hexdocs.pm/sourceror/Sourceror.html | [`../../cache/041-sourceror.html`](../../cache/041-sourceror.html) | Source-aware AST tooling, traversal, comments, ranges, patches, codemods, and rendering. |

## Topics

| Topic | Notes |
|---|---|
| `mix-task` | Main CLI integration point for CRAP.ex. |
| `cli-behavior` | Switches, filters, stdin/diff/watch modes, and shell status. |
| `static-analysis` | Credo and Sobelow as analyzer UX references. |
| `ast` | Elixir quoted AST as the basis for source analysis. |
| `source-parsing` | Sourceror when preserving locations/comments matters. |
| `hex-package` | Publishing, docs, and package metadata constraints. |
| `library-design` | Explicit options and stable public APIs. |

## Cross-Links

- [`../complexity/`](../complexity/) explains metric choices that the tooling must compute.
- [`../coverage/`](../coverage/) covers coverage inputs that the tooling must ingest or coordinate with.
- [`../ci-reporting/`](../ci-reporting/) covers output formats and exit behavior for automation.
- [`../prior-art/`](../prior-art/) gives CLI/reporting examples from other ecosystems.
