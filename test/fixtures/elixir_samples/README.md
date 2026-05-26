# Elixir CRAP Metrics Test Samples

A curated archive of Elixir source files for testing a CRAP (complexity + test coverage) metrics analysis library.

## Structure

```
elixir_samples/
├── 01_basic_modules/        # defmodule, def/defp, guards, default args, @doc/@spec
├── 02_typespecs/            # @type, @typep, @opaque, @spec, @callback, union/recursive types
├── 03_structs_protocols/    # defstruct, @enforce_keys, defimpl Inspect/String.Chars
├── 04_behaviours/           # @behaviour, @callback, @optional_callbacks, @impl
├── 05_macros/               # defmacro, __using__, @before_compile, quote/unquote/unquote_splicing
├── 06_pattern_matching/     # case/cond/with, pin operator, multi-clause, nested destructuring
├── 07_genserver/            # use GenServer, all callbacks, :erlang.send_after, client API
├── 08_supervisors_otp/      # use Application, use Supervisor, Agent, Task.Supervisor, child_spec
├── 09_protocols/            # defprotocol, @fallback_to_any, 11 defimpl blocks, defdelegate
├── 10_advanced/             # defexception, raise/rescue, try/catch, Stream, for, Bitwise, backoff
└── _raw_originals/          # 28 unmodified source files from OSS Elixir libraries
```

## Canonical Samples (directories 01–10)

Self-contained `.ex` files that compile standalone — no missing module references.
Each is inspired by real-world Elixir library patterns but rewritten to be independent.

| Dir | File | Lines | Complexity | Key Constructs |
|-----|------|-------|------------|----------------|
| 01 | simple_math.ex | ~55 | Simple | def/defp, guards, default args, @spec |
| 01 | string_processor.ex | ~95 | Moderate | Multi-clause, binary matching, recursion, pipeline |
| 02 | serializer.ex | ~145 | Moderate | @type/@typep/@opaque/@spec/@callback, unions, recursive types |
| 03 | measurement.ex | ~150 | Moderate | defstruct, @enforce_keys, defimpl Inspect/String.Chars |
| 04 | pipeline.ex | ~160 | Moderate | @behaviour, @callback, @optional_callbacks, @impl, 4 impls |
| 05 | registerable.ex | ~105 | Complex | defmacro, __using__, @before_compile, quote/unquote_splicing |
| 06 | data_validator.ex | ~260 | Complex | case/cond/with, pin operator, nested matching, tagged tuples |
| 07 | cache_janitor.ex | ~210 | Moderate | use GenServer, all 4 callbacks, :erlang.send_after, state mgmt |
| 08 | sample_app.ex | ~190 | Moderate | Application, Supervisor, Agent, Task.Supervisor, child_spec |
| 09 | renderable.ex | ~120 | Moderate | defprotocol, @fallback_to_any, 11 defimpl, defdelegate |
| 10 | task_runner.ex | ~245 | Complex | defexception, raise/rescue, try/catch, Stream, for, Bitwise |

## Raw Originals (_raw_originals/)

28 unmodified source files cloned from these OSS repositories:

- **Jason** (michalmuskala/jason) — jason.ex, encoder.ex, encode.ex, codegen.ex, formatter.ex, fragment.ex, helpers.ex, ordered_object.ex, sigil.ex
- **Plug** (elixir-plug/plug) — plug.ex, builder.ex
- **Decimal** (ericmj/decimal) — decimal.ex (2,860 lines)
- **Tesla** (elixir-tesla/tesla) — bearer_auth.ex, retry.ex
- **Broadway** (dashbitco/broadway) — message.ex, topology.ex
- **GenStage** (elixir-lang/gen_stage) — producer_consumer.exs, gen_event.exs, consumer_supervisor.exs, rate_limiter.exs
- **Phoenix.HTML** (phoenixframework/phoenix_html) — safe.ex, engine.ex
- **Cachex** (whitfin/cachex) — janitor.ex
- **Elixir core** (elixir-lang/elixir) — gen_server.ex, exception.ex, mix/exceptions.ex
- **Money** (elixirmoney/money) — money.ex
- **Ecto** (elixir-ecto/ecto) — changeset.ex (4,421 lines)

**Note:** Raw originals reference external modules and will NOT compile standalone.
They are included as reference material and for comparing against the canonical samples.
