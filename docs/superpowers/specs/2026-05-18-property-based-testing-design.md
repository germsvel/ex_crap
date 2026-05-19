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

This will introduce the project's first external dependency and create `mix.lock`. Both files are in scope for the implementation.

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

Use generated models shaped around analyzer semantics rather than arbitrary Elixir. Keep models explicit enough that expected scores can be derived mechanically without guessing what a shorthand construct means:

```elixir
%{
  module: "GeneratedExample",
  function: "run",
  definition_kind: :def,
  arity: 1,
  declaration_head?: true,
  clauses: [
    %{
      guard: %{operators: [:and]},
      body: [
        %{kind: :if, boolean_operators: []},
        %{kind: :case, branches: 2, clause_guard_operators: []},
        %{kind: :with, generators: 1, else_branches: 1}
      ]
    }
  ],
  expected_kind: :ok
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

Do not store a precomputed complexity in the generated model. Compute it at assertion time from the final shrunk model so shrinking cannot leave stale expected values behind.

Each construct model should encode the exact scoring inputs used by the analyzer rule being tested:

- Boolean expressions store operator sequences, not only a count.
- `case`, `cond`, `receive`, and anonymous function bodies store branch counts and any arrow-clause guard operators.
- `with` stores generator count and `else` branch count separately.
- `try` stores whether the base `try` exists plus separate `else`, `rescue`, and `catch` branch counts.
- `for` stores generator count and filter count separately.
- `receive` stores branch count and whether an `after` timeout branch exists.

The first implementation should include only the construct models it needs for phase 1. Add new construct models incrementally as new properties are added.

## Phase 1 Generator Scope

Start with a narrow set of focused generators. The goal is useful, debuggable properties, not maximum syntax breadth in one generator.

Phase 1 should include:

- Definition kinds: `def`, `defp`, `defmacro`, `defmacrop`.
- Clause counts: one to three implementation clauses.
- Optional valid bodyless declaration heads that match a later implementation clause.
- Invalid bodyless declaration heads with no matching implementation.
- Invalid declaration heads implemented by a different definition kind.
- Guard decisions using short boolean `and`, `or`, `&&`, and `||` chains.
- A small body construct subset: `if`, `case`, and `with`.
- Valid non-analyzable source forms such as empty modules, protocol callback declarations, and callback-only behavior modules.

Phase 1 should not generate valid `defimpl` scoring cases, nested modules, `Module.concat`, `__MODULE__` module names, multiple protocol targets, `try`, `for`, `receive`, `cond`, or anonymous function clauses. Those are important, but they should be added as explicit follow-up properties after the first suite is stable.

Keep recursion shallow. Phase 1 should generate flat bodies only. Deep nesting can be added later if the first suite is stable and useful.

Use separate focused generators for major behavior groups instead of one broad generator:

- Valid scoring generator for functions and macros.
- Valid declaration-head generator.
- Invalid declaration-head generator.
- Valid non-analyzable-source generator.

This keeps `max_runs: 50` meaningful because each property explores a narrower input space.

## Phase 1 Properties

Add properties that cover both positive and negative behavior:

- Valid generated functions always return `{:ok, [result]}` for the generated module/function/arity.
- Returned complexity equals the model-derived expected complexity.
- Multi-clause functions aggregate by `{module, function, arity}` and sum one base path per implementation clause plus each clause's generated guard/body decisions.
- Valid matching bodyless declaration heads do not produce `:invalid_source` and do not add separate result rows.
- Bodyless supported definitions with no matching implementation return `{:error, :invalid_source}`.
- Bodyless declarations implemented by a different definition kind return `{:error, :invalid_source}`.
- Valid generated non-analyzable source returns `{:ok, []}`.

The existing example tests should remain. Property tests are an additional safety net and should not replace targeted regression tests for known bugs.

Declaration-head validity must be context-specific:

- Bodyless supported definitions inside `defmodule` and `defimpl` are invalid unless matched by an implementation of the same definition kind, function name, and arity.
- Bodyless callback declarations inside `defprotocol` are valid non-analyzable source and should be generated by the non-analyzable-source property, not the invalid-declaration property.
- A declaration head must never contribute its own result row or base complexity.

## Follow-Up Properties

After phase 1 is passing and maintainable, add follow-up properties for broader syntax coverage:

- Valid `defimpl` scoring, including protocol/target module resolution.
- Nested module context.
- `Module.concat` and `__MODULE__` module forms.
- Multiple `defimpl` targets.
- Additional body constructs: `cond`, `try`, `for`, `receive`, and anonymous function clauses.
- Lightly nested body constructs.

## Test Runtime

Use conservative defaults for the first suite so local `mix test` remains fast. Prefer per-property options such as `max_runs: 50` while the generators are new. Increase run counts later after the suite proves stable.

If CI-specific tuning is needed later, prefer per-property options first. If project-wide StreamData configuration becomes necessary, add a real Mix config tree, including `config/config.exs` that imports environment-specific config, before adding `config/test.exs`. Configuration can tune `max_runs`, `max_run_time`, and `max_shrinking_steps`; do not add project-wide configuration until there is evidence that per-property options are insufficient.

## Failure Diagnostics

When assertions fail, include the rendered source and the generated model in assertion messages or surrounding variables so ExUnit output is actionable. The key diagnostic artifact should be the minimal rendered Elixir source that reproduces the mismatch.

Property failures should be reproducible with the ExUnit seed printed by `mix test`.

## Implementation Notes

Keep the first implementation minimal:

- Add `StreamData` as a test-only dependency.
- Add a new property test file.
- Keep model generators, renderer, and expected-score calculation in that file.
- Split properties by focused generator instead of building one broad generator.
- Run the new property test file first, then the full suite.

If the helper code grows enough to obscure the properties, move it later to `test/support/complexity_case_generator.ex`. That refactor is not part of the initial design.

## Success Criteria

The work is complete when:

- Property tests run through normal `mix test`.
- Existing deterministic tests still pass.
- The new properties cover valid complexity scoring, valid declaration heads, invalid declaration heads, and valid non-analyzable source.
- A failing generated case would print enough information to reproduce the analyzer input as a source string.
