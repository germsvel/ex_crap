# ExCrap Project Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the Mix project and public Elixir namespace from `crap`/`Crap` to `ex_crap`/`ExCrap` while preserving the `mix crap` command.

**Architecture:** The OTP application name becomes `:ex_crap`, and the public modules move under `ExCrap`. The Mix task module remains `Mix.Tasks.Crap`, because Mix derives the CLI task name from that module name.

**Tech Stack:** Elixir, Mix, ExUnit.

---

## File Structure

- Rename `lib/crap.ex` to `lib/ex_crap.ex`; define `ExCrap` public API.
- Rename `lib/crap/*.ex` to `lib/ex_crap/*.ex`; define `ExCrap.Complexity`, `ExCrap.Coverage`, `ExCrap.Report`, and `ExCrap.Scanner`.
- Keep `lib/mix/tasks/crap.ex`; update implementation references from `Crap.*` to `ExCrap.*` while preserving `Mix.Tasks.Crap`.
- Rename `test/crap_test.exs` to `test/ex_crap_test.exs`; update public API assertions.
- Rename `test/crap/*.exs` to `test/ex_crap/*.exs`; update test module names and namespace references.
- Keep `test/mix/tasks/crap_test.exs`; update expected report module names where fixtures use the project namespace.
- Update `mix.exs` from `Crap.MixProject`/`:crap` to `ExCrap.MixProject`/`:ex_crap`.
- Update `README.md` examples from `Crap.*` to `ExCrap.*`, while retaining all `mix crap` examples.

### Task 1: Assert New Public Namespace

**Files:**
- Modify: `test/crap_test.exs`
- Modify: `test/crap/complexity_test.exs`
- Modify: `test/crap/coverage_test.exs`
- Modify: `test/crap/report_test.exs`
- Modify: `test/crap/scanner_test.exs`
- Modify: `test/crap/complexity_property_test.exs`
- Modify: `test/mix/tasks/crap_test.exs`

- [ ] **Step 1: Update tests to expect `ExCrap` modules**

Change test module names and calls from `Crap` to `ExCrap`, and from `Crap.*` to `ExCrap.*`. Keep `Mix.Tasks.Crap` tests unchanged except where fixture source strings or expected output mention the public namespace.

- [ ] **Step 2: Run focused tests to verify failure**

Run: `mix test test/ex_crap_test.exs test/ex_crap test/mix/tasks/crap_test.exs`

Expected: FAIL until source modules are renamed.

### Task 2: Rename Source Modules and Application

**Files:**
- Modify: `mix.exs`
- Move: `lib/crap.ex` to `lib/ex_crap.ex`
- Move: `lib/crap/complexity.ex` to `lib/ex_crap/complexity.ex`
- Move: `lib/crap/coverage.ex` to `lib/ex_crap/coverage.ex`
- Move: `lib/crap/report.ex` to `lib/ex_crap/report.ex`
- Move: `lib/crap/scanner.ex` to `lib/ex_crap/scanner.ex`
- Modify: `lib/mix/tasks/crap.ex`

- [ ] **Step 1: Rename Mix project metadata**

Set `defmodule ExCrap.MixProject` and `app: :ex_crap` in `mix.exs`.

- [ ] **Step 2: Rename source files and modules**

Move the public API and supporting modules to `lib/ex_crap*` and update `defmodule` declarations to `ExCrap*`.

- [ ] **Step 3: Preserve Mix task name**

Keep `defmodule Mix.Tasks.Crap` in `lib/mix/tasks/crap.ex`, but update all implementation calls to `ExCrap.Scanner`, `ExCrap.Coverage`, and `ExCrap.Report`.

- [ ] **Step 4: Run focused tests to verify pass**

Run: `mix test test/ex_crap_test.exs test/ex_crap test/mix/tasks/crap_test.exs`

Expected: PASS.

### Task 3: Update Documentation and Full Verification

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update README API examples**

Replace `Crap.score/2` and `Crap.analyze_string/2` examples with `ExCrap.score/2` and `ExCrap.analyze_string/2`. Keep `mix crap` command examples unchanged.

- [ ] **Step 2: Format source and tests**

Run: `mix format`

Expected: exits 0.

- [ ] **Step 3: Run full tests**

Run: `mix test`

Expected: PASS.

## Self-Review

- Spec coverage: The plan renames OTP app metadata, public namespace, source/test paths, tests, and docs while preserving `Mix.Tasks.Crap`.
- Placeholder scan: No `TBD` or open implementation placeholders remain.
- Type consistency: All target module names use `ExCrap`; the only retained `Crap` module is `Mix.Tasks.Crap` for the CLI task name.
