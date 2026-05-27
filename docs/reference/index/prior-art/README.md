# Prior Art

## Purpose

This section indexes existing CRAP and CRAP-inspired tools. It focuses on implementation patterns, coverage input formats, scoring behavior, CLI design, outputs, thresholds, and ideas worth borrowing for CRAP.ex.

## Key Takeaways

- Mature implementations separate complexity extraction, coverage parsing, merge/join logic, scoring, reporting, config, and CI behavior.
- Coverage input formats vary by ecosystem: Cobertura XML, SimpleCov JSON, LCOV, and commercial/export-specific formats.
- Missing coverage should be handled explicitly; `cargo-crap` uses a pessimistic `0%` policy for functions with no coverage data.
- Reports should be sortable and action-oriented: file/function, score, complexity, coverage, totals, averages, and worst offenders.
- CRAP-inspired variants expand the signal beyond cyclomatic complexity: Skunk uses code smells, ABC complexity, churn, and coverage.
- Useful CLI dimensions include paths, excludes, output destination, output format, branch/baseline comparison, and threshold gates.
- Good tools serve both local developers and CI by supporting console output plus machine-readable formats.

## Source Map

| Source | URL | Local Cache | Usefulness |
|---|---|---|---|
| crap4java repository | https://github.com/unclebob/crap4java | [`../../cache/006-crap4java.html`](../../cache/006-crap4java.html) | Java lineage and repository context, limited cached implementation detail. |
| GMetrics `CrapMetric` docs | https://dx42.github.io/gmetrics/metrics/CrapMetric.html | [`../../cache/007-gmetrics-crapmetric.html`](../../cache/007-gmetrics-crapmetric.html) | Formula, threshold, composite metric design, Cobertura input, configurable functions, and metric provider injection. |
| FastRuby Skunk introduction | https://www.fastruby.io/blog/code-quality/introducing-skunk-stink-score-calculator.html | [`../../cache/008-fastruby-skunk.html`](../../cache/008-fastruby-skunk.html) | SkunkScore model, RubyCritic cost, smells, ABC complexity, churn, SimpleCov input, report shape, caveats. |
| Skunk README | https://github.com/fastruby/skunk/blob/main/README.md | [`../../cache/009-skunk-readme.html`](../../cache/009-skunk-readme.html) | Install, SimpleCov input, CLI flags, path filtering, branch comparison, output file, JSON/HTML/console reports. |
| Skunk dev.to article | https://dev.to/etagwerker/introducing-skunk-combine-code-quality-and-coverage-to-calculate-a-stink-score-6f4 | [`../../cache/010-devto-skunk.html`](../../cache/010-devto-skunk.html) | Original Stink Score framing and examples. |
| Qt Coco documentation | https://www.qt.io/quality-assurance/coco | [`../../cache/033-qt-coco.html`](../../cache/033-qt-coco.html) | Commercial coverage/reporting patterns, patch coverage, diff import, exports, and CI threshold enforcement. |
| `cargo-crap` docs | https://docs.rs/cargo-crap/latest/cargo_crap/ | [`../../cache/043-cargo-crap.html`](../../cache/043-cargo-crap.html) | Modern implementation pattern: AST complexity, LCOV parsing, missing coverage policy, threshold, JSON/GitHub/Markdown output, baseline mode, CI gating. |

## Topics

| Topic | Notes |
|---|---|
| `coverage-format` | Cobertura, SimpleCov, LCOV, SonarQube, JUnit, HTML/XML/CSV exports. |
| `missing-coverage-policy` | Whether absent coverage means unknown, skipped, or zero. |
| `report-shape` | Sortable score tables and summary statistics. |
| `baseline-delta` | Compare against branch or prior baseline to reduce noise. |
| `technical-debt` | Skunk-style expansion beyond the original CRAP formula. |
| `ci-gates` | Thresholds and non-zero exits for automation. |

## Cross-Links

- [`../crap-metric/`](../crap-metric/) gives the canonical formula these tools implement or adapt.
- [`../coverage/`](../coverage/) maps prior-art coverage formats to Elixir coverage realities.
- [`../elixir-tooling/`](../elixir-tooling/) covers how to translate prior-art CLI patterns into Mix tasks.
- [`../ci-reporting/`](../ci-reporting/) covers machine-readable outputs and automation behavior.
