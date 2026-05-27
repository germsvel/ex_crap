# Complexity

## Purpose

This section indexes sources about complexity metrics and related maintainability signals. It clarifies why cyclomatic complexity is the historical CRAP input, why cognitive complexity exists, and where Elixir-specific code smells may matter later.

## Key Takeaways

- Cyclomatic complexity is the historical CRAP input and is based on control-flow decision structure.
- Cyclomatic complexity aligns well with path/test burden, but it is not a complete model of human understandability.
- Cognitive complexity was designed to better reflect developer comprehension by penalizing breaks in linear flow and nesting.
- The cognitive complexity empirical study supports correlations with comprehension time and subjective understandability, but evidence is mixed for correctness alone.
- Metric validation is uneven, so CRAP.ex should describe complexity as a proxy rather than a definitive diagnosis.
- Elixir-specific maintainability issues are not fully captured by generic branch-count metrics.
- A pragmatic CRAP.ex default should preserve cyclomatic complexity compatibility while documenting possible future cognitive-complexity or smell-aware extensions.

## Source Map

| Source | URL | Local Cache | Usefulness |
|---|---|---|---|
| Cognitive complexity empirical study, abstract | https://arxiv.org/abs/2007.12520 | [`../../cache/004-arxiv-2007-12520.html`](../../cache/004-arxiv-2007-12520.html) | Abstract-level summary of study design and validation results. |
| Cognitive complexity empirical study, PDF | https://arxiv.org/pdf/2007.12520 | [`../../cache/005-arxiv-2007-12520.pdf`](../../cache/005-arxiv-2007-12520.pdf) | Full study with metric rules, methodology, limitations, and cyclomatic-vs-cognitive comparison. |
| McCabe, "A Complexity Measure" | https://ieeexplore.ieee.org/document/1702388 | [`../../cache/027-mccabe-complexity-measure.html`](../../cache/027-mccabe-complexity-measure.html) | Canonical source for cyclomatic complexity lineage and graph-theoretic framing. |
| Elixir code smells grey-literature review | https://arxiv.org/abs/2203.08877 | [`../../cache/044-arxiv-2203-08877.html`](../../cache/044-arxiv-2203-08877.html) | Elixir-specific smell context and evidence that existing tools do not cover all maintainability risks. |

## Topics

| Topic | Notes |
|---|---|
| `cyclomatic-complexity` | Historical baseline for CRAP and many static-analysis tools. |
| `cognitive-complexity` | Alternative aimed at human understandability. |
| `metric-validity` | Empirical support, limitations, and interpretation risk. |
| `code-smells` | Future complementary signal for Elixir maintainability. |
| `test-burden` | Why complexity matters when combined with coverage. |

## Cross-Links

- [`../crap-metric/`](../crap-metric/) documents how complexity enters the CRAP formula.
- [`../elixir-tooling/`](../elixir-tooling/) includes Credo and AST parsing sources relevant to computing complexity in Elixir.
- [`../coverage/`](../coverage/) explains why uncovered complexity is the risky combination CRAP targets.
- [`../prior-art/`](../prior-art/) shows implementations that use cyclomatic complexity, ABC complexity, or richer cost models.
