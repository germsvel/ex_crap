# CI Reporting

## Purpose

This section indexes sources about how CRAP.ex should behave in automation: output formats, stable issue records, exit statuses, Code Climate-compatible reports, GitHub Actions workflows, coverage upload paths, and release packaging.

## Key Takeaways

- Provide explicit output formats for CI; at minimum human text and JSON, with SARIF or Code Climate-compatible JSON as likely future targets.
- Separate “issues found” from “tool crashed.” Code Climate engines emit findings with exit `0` and reserve non-zero exits for fatal failures.
- A reporting-only switch like Credo's `--mute-exit-status` is useful for teams that want data before enforcing gates.
- Code Climate issue records need a type, check name, one-line description, categories, location, optional content, remediation points, severity, and deterministic fingerprint.
- Locations should use repository-relative paths and stable one-based line ranges or line/column positions.
- GitHub Actions coverage uploads require careful report paths, especially in monorepos.
- Hex publishing imposes docs, package metadata, dry-run, and package-size concerns that affect release quality.

## Source Map

| Source | URL | Local Cache | Usefulness |
|---|---|---|---|
| Credo CLI switches | https://hexdocs.pm/credo/cli_switches.html | [`../../cache/018-credo-cli-switches.html`](../../cache/018-credo-cli-switches.html) | Model for CLI output formats, color control, strict mode, mute exit status, stdin, and filters. |
| Code Climate analyzer spec | https://github.com/codeclimate/platform/blob/master/spec/analyzers/SPEC.md | [`../../cache/022-codeclimate-spec.html`](../../cache/022-codeclimate-spec.html) | Canonical issue shape, streaming JSON protocol, locations, categories, severity, and fatal vs non-fatal exit semantics. |
| Code Climate GitHub Action | https://github.com/paambaati/codeclimate-action | [`../../cache/023-codeclimate-action.html`](../../cache/023-codeclimate-action.html) | GitHub Actions coverage upload examples, secrets, coverage location formats, and deprecation context. |
| Credo exit statuses | https://hexdocs.pm/credo/exit_statuses.html | [`../../cache/040-credo-exit-statuses.html`](../../cache/040-credo-exit-statuses.html) | Elixir precedent for CI failure semantics and category bitmask statuses. |
| Hex publish docs | https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html | [`../../cache/024-hex-publish.html`](../../cache/024-hex-publish.html) | Release and packaging implications, docs publishing, dry-run, package metadata, and size limits. |

## Topics

| Topic | Notes |
|---|---|
| `json-output` | Stable machine-readable findings and summary records. |
| `code-climate` | Issue schema, categories, fingerprints, and locations. |
| `exit-status` | Distinguish findings, strict gates, muted gates, and fatal tool errors. |
| `github-actions` | Coverage locations, secrets, and CI integration. |
| `deterministic-fingerprint` | Stable identity for repeated findings. |
| `hex-publish` | Release quality and package documentation constraints. |

## Cross-Links

- [`../crap-metric/`](../crap-metric/) defines what thresholds and severities mean.
- [`../coverage/`](../coverage/) covers the coverage data and reports that CI may upload.
- [`../elixir-tooling/`](../elixir-tooling/) covers Mix task and Credo-style CLI behavior.
- [`../prior-art/`](../prior-art/) shows GitHub annotations, JSON, Markdown, and CI gates in other tools.
