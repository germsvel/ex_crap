# Property-Based Complexity Testing Design

## Goal

Introduce property-based tests that supplement the existing example-based ExUnit tests for `Crap.Complexity.from_string/1`. The properties should generate many combinations of supported Elixir syntax and verify that valid combinations produce expected complexity scores while invalid combinations return `{:error, :invalid_source}`.

The first property suite should focus on the analyzer. Scanner and Mix task behavior should remain covered by deterministic examples unless a future bug shows that file-system-level property tests would add value.

## Library Choice

Use `StreamData`.

Add the dependency as test-only:

```elixir
{:stream_data, "~> 1.3", only: :test}
```

Rationale:

- `StreamData` integrates directly with ExUnit through `use ExUnitProperties`, `property`, and `check all`.
- It has an Apache-2.0 license and no runtime dependencies.
- Its generator API is enough for syntax-model generation and shrinking.
- It uses ExUnit seeds by default, so failing property runs can be reproduced with the standard `mix test --seed <seed>` workflow.

Do not use `PropCheck` for the first version. PropCheck is useful for state-machine and PropEr-style testing, but this project needs composable data generators more than stateful command testing. It also brings GPL-3.0 licensing and additional conceptual overhead.

## Alternatives Considered

### Structured Source Model and Renderer

Generate a small internal model that represents syntax cases, render that model to Elixir source, and compute the expected result from the model.

This is the recommended approach because it produces valid, intentional source most of the time and gives useful shrinking. A failing case can be inspected as a small model and as rendered Elixir source.

### Raw Source String Generation

Generate arbitrary source strings or loosely templated source snippets.

This may find parser boundary cases, but it will produce many irrelevant invalid inputs. Shrinking will often return malformed strings that obscure the semantic issue being tested.

### Quoted AST Generation

Generate quoted expressions and render them with `Macro.to_string/1`.

This avoids hand-written source rendering, but it can miss source-level shapes that matter for this analyzer, including bodyless declaration heads, keyword-form `defimpl`, and block syntax variants.

## Test Model

Create `test/crap/complexity_property_test.exs` with property helpers local to the test module at first. Do not add production test-support modules unless the helpers become too large to keep readable.

Use a generated model shaped around analyzer semantics rather than arbitrary Elixir:

```elixir
%{
  module: "GeneratedExample",
  function: "run",
  definition_kind: :def,
  arity: 1,
  declaration_head?: true,
  clauses: [
    %{
      guard_decisions: 1,
      body_constructs: [:if, {:case, 2}, {:with_else, 1}]
    }
  ],
  expected: {:ok, 6}
}
```

The renderer should turn the model into a source string such as:

```elixir
defmodule GeneratedExample do
  def run(value)

  def run(value) when is_integer(value) and value > 0 do
    if value do
      :ok
    else
      :error
    end
  end
end
```

The expected complexity should be computed from the model, not by calling analyzer internals. This keeps the property independent enough to catch analyzer mistakes while staying simple and explicit.

## Initial Generator Scope

Start with bounded syntax combinations that map directly to current analyzer rules:

- Definition kinds: `def`, `defp`, `defmacro`, `defmacrop`.
- Clause counts: one to three implementation clauses.
- Optional valid bodyless declaration heads that match a later implementation clause.
- Invalid bodyless declaration heads with no matching implementation.
- Invalid declaration heads implemented by a different definition kind.
- Guard decisions using boolean `and`, `or`, `&&`, and `||` chains.
- Body decision constructs for `if`, `unless`, `case`, `cond`, `with`, `try`, `for`, `receive`, and anonymous function clauses.
- Valid non-analyzable source forms such as empty modules, protocol callback declarations, and callback-only behavior modules.

Keep recursion shallow. A good first pass should generate flat or lightly nested bodies. Deep nesting can be added later if the first suite is stable and useful.

## Initial Properties

Add properties that cover both positive and negative behavior:

- Valid generated functions always return `{:ok, [result]}` for the generated module/function/arity.
- Returned complexity equals the model-derived expected complexity.
- Valid matching bodyless declaration heads do not produce `:invalid_source` and do not add separate result rows.
- Bodyless supported definitions with no matching implementation return `{:error, :invalid_source}`.
- Bodyless declarations implemented by a different definition kind return `{:error, :invalid_source}`.
- Valid generated non-analyzable source returns `{:ok, []}`.

The existing example tests should remain. Property tests are an additional safety net and should not replace targeted regression tests for known bugs.

## Test Runtime

Use conservative defaults for the first suite so local `mix test` remains fast. Prefer per-property options such as `max_runs: 50` while the generators are new. Increase run counts later after the suite proves stable.

If CI-specific tuning is needed later, add `config/test.exs` with `config :stream_data, max_runs: ...`. Do not add configuration until there is evidence that per-property options are insufficient.

## Failure Diagnostics

When assertions fail, include the rendered source and the generated model in assertion messages or surrounding variables so ExUnit output is actionable. The key diagnostic artifact should be the minimal rendered Elixir source that reproduces the mismatch.

Property failures should be reproducible with the ExUnit seed printed by `mix test`.

## Implementation Notes

Keep the first implementation minimal:

- Add `StreamData` as a test-only dependency.
- Add a new property test file.
- Keep model generators, renderer, and expected-score calculation in that file.
- Run the new property test file first, then the full suite.

If the helper code grows enough to obscure the properties, move it later to `test/support/complexity_case_generator.ex`. That refactor is not part of the initial design.

## Success Criteria

The work is complete when:

- Property tests run through normal `mix test`.
- Existing deterministic tests still pass.
- The new properties cover valid complexity scoring, valid declaration heads, invalid declaration heads, and valid non-analyzable source.
- A failing generated case would print enough information to reproduce the analyzer input as a source string.
