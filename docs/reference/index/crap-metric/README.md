# CRAP Metric

## Purpose

This section indexes sources that define CRAP, explain where it came from, document the canonical formula, and frame how it should be interpreted by CRAP.ex.

## Key Takeaways

- CRAP originated in the Crap4J work by Alberto Savoia and Bob Evans as a change-risk metric that combines complexity and coverage.
- The canonical method/function formula is `CRAP(m) = comp(m)^2 * (1 - cov(m)/100)^3 + comp(m)`.
- The common threshold is `30`; values above that are treated as risky, but the threshold is empirical rather than mathematically absolute.
- High coverage can offset moderate complexity, but very high complexity cannot be rescued by coverage alone.
- Remediation is intentionally practical: add meaningful tests, reduce complexity, or add tests before refactoring risky legacy code.
- CRAP is best presented as a prioritization signal, not a moral judgment or a complete maintainability measure.
- The metric ignores important qualities such as coupling, cohesion, naming, readability, domain complexity, and test quality.

## Source Map

| Source | URL | Local Cache | Usefulness |
|---|---|---|---|
| Alberto Savoia, "The Code C.R.A.P. Metric Hits the Fan" | https://www.artima.com/weblogs/viewpost.jsp?thread=215899 | [`../../cache/001-artima-crap.html`](../../cache/001-artima-crap.html) | Canonical origin, original formula, threshold table, interpretation, aggregate notes, and caveats. |
| Crap4j FAQ | http://www.crap4j.org/faq.html | [`../../cache/002-crap4j-faq.html`](../../cache/002-crap4j-faq.html) | Concise definition, formula, threshold table, remediation guidance, and CRAP load framing. |
| OtterWise CRAP and cyclomatic complexity overview | https://getotterwise.com/blog/understanding-crap-and-cyclomatic-complexity-metrics | [`../../cache/003-otterwise-crap-complexity.html`](../../cache/003-otterwise-crap-complexity.html) | Modern practitioner explanation, score bands, PR trend framing, and caveats around averages. |
| Google Testing Blog, "This Code is CRAP" | https://testing.googleblog.com/2011/02/this-code-is-crap.html | [`../../cache/026-google-testing-crap.html`](../../cache/026-google-testing-crap.html) | Retrospective from Savoia, history, empirical derivation, adoption, and limitations. |

## Topics

| Topic | Notes |
|---|---|
| `crap-formula` | Original CRAP formula and function-level scoring semantics. |
| `threshold-30` | Historical score threshold for flagging risky functions. |
| `coverage-vs-complexity` | How increasing complexity requires increasing coverage. |
| `change-risk` | CRAP is about risk of changing code, not broad code quality. |
| `remediation` | Add tests, simplify code, or test before refactoring. |
| `metric-caveats` | Coverage quality and design quality are outside the formula. |

## Cross-Links

- [`../complexity/`](../complexity/) explains the complexity side of the formula and alternatives to cyclomatic complexity.
- [`../coverage/`](../coverage/) explains how Elixir/Erlang coverage data can feed the coverage side of the formula.
- [`../prior-art/`](../prior-art/) shows how other tools implement CRAP or CRAP-like scores.
- [`../ci-reporting/`](../ci-reporting/) covers how thresholds become automation behavior.
