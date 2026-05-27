# Reference Index

This directory is a semantic index over the cached research corpus in `docs/reference/cache/`. It is a finding aid: use it to decide which cached source to open, which topic a source supports, and how the sources connect to implementation decisions for CRAP.ex.

## Corpus Status

- Manifest: [`../urls.md`](../urls.md)
- Cache directory: [`../cache/`](../cache/)
- Usable cached sources: 43
- Uncached sources: 1, blocked by Cloudflare challenge
- Index model: layered topic index with cross-links between sections

## Sections

| Section | Use It For |
|---|---|
| [`crap-metric`](crap-metric/) | CRAP origin, formula, threshold semantics, and interpretation caveats. |
| [`complexity`](complexity/) | Cyclomatic complexity, cognitive complexity, code smells, and metric validity. |
| [`coverage`](coverage/) | Erlang/Elixir coverage data, Mix coverage tasks, exports, and cross-language coverage examples. |
| [`elixir-tooling`](elixir-tooling/) | Mix task design, Credo-style analysis, AST/source parsing, packaging, and adjacent Elixir tools. |
| [`prior-art`](prior-art/) | Existing CRAP and CRAP-inspired implementations across Java, Groovy, Ruby, Rust, PHP, and commercial tools. |
| [`ci-reporting`](ci-reporting/) | CI behavior, output formats, Code Climate issue shape, exit statuses, and publishing implications. |
| [`source-inventory`](source-inventory/) | Complete source inventory with local cache paths, status, and primary topics. |

## Topic Map

| Topic | Primary Sections | Representative Sources |
|---|---|---|
| CRAP formula and thresholds | [`crap-metric`](crap-metric/), [`prior-art`](prior-art/) | Savoia Artima post, Crap4j FAQ, GMetrics, `cargo-crap` |
| Complexity metric choice | [`complexity`](complexity/), [`elixir-tooling`](elixir-tooling/) | McCabe, cognitive complexity study, Credo cyclomatic complexity |
| Coverage collection | [`coverage`](coverage/), [`elixir-tooling`](elixir-tooling/) | Erlang `:cover`, `mix test --cover`, ExCoveralls, covertool |
| Elixir implementation shape | [`elixir-tooling`](elixir-tooling/), [`ci-reporting`](ci-reporting/) | `Mix.Task`, Credo switches, Sourceror, Hex publishing |
| Prior-art CLI/reporting | [`prior-art`](prior-art/), [`ci-reporting`](ci-reporting/) | Skunk, `cargo-crap`, Qt Coco, Code Climate spec |
| Risk interpretation | [`crap-metric`](crap-metric/), [`complexity`](complexity/), [`coverage`](coverage/) | Google Testing Blog, OtterWise, cognitive complexity study, PHPUnit coverage docs |

## Reading Paths

Start with [`crap-metric`](crap-metric/) if you need the definition of CRAP and its original semantics.

Start with [`coverage`](coverage/) if you are designing how CRAP.ex obtains coverage data from Elixir projects.

Start with [`elixir-tooling`](elixir-tooling/) if you are designing the Mix task, parser, CLI options, or library packaging.

Start with [`prior-art`](prior-art/) if you are deciding output formats, threshold behavior, missing coverage policy, or report shape.

Start with [`ci-reporting`](ci-reporting/) if you are making CRAP.ex useful in automation, PR checks, Code Climate-compatible reports, or release workflows.

## Reusable Tags

`crap-metric`, `change-risk`, `cyclomatic-complexity`, `cognitive-complexity`, `coverage-data-shape`, `erlang-cover`, `mix-task`, `static-analysis`, `ast`, `source-parsing`, `ci`, `json-output`, `code-climate`, `github-actions`, `exit-status`, `cobertura`, `lcov`, `simplecov`, `thresholds`, `baseline-delta`, `technical-debt`.
