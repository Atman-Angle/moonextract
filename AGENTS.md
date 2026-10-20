# Repository Guidelines

MoonExtract is a pure MoonBit library for connecting extracted values to
verbatim source evidence. Keep the core package offline, deterministic, and
model-agnostic; LLM adapters, OCR, PDF parsing, and web UI are out of scope for
the first phase.

## Project Structure & Module Organization

- Root `.mbt` files hold the library plus blackbox (`*_test.mbt`) and whitebox
  (`*_wbtest.mbt`) tests.
- `cmd/main/` contains the runnable demonstration; keep `main.mbt` thin and move
  reusable logic into the library.
- `docs/` contains architecture and acceptance notes. `moon.mod` holds module
  metadata; each package declares dependencies in its `moon.pkg`.
- Do not commit `_build/`, local caches, credentials, or unverified extraction
  claims.

## Build, Test, and Development Commands

Run these from the repository root in PowerShell 7:

```powershell
moon fmt                 # format sources
moon check               # type-check all packages
moon test                # run the full test suite
moon run cmd/main        # run the demonstration CLI
moon info                # refresh public interfaces after API changes
```

Enable the checked-in pre-commit hook with
`git config core.hooksPath .githooks`; it runs `moon check`.

## Coding Style & Naming Conventions

Use `moon fmt` output and two-space indentation. Separate definitions with
`///|`. Use `snake_case` for functions, values, and source files; `UpperCamelCase`
for types; and lowercase package names. Expose public APIs explicitly. Return
`Result` for recoverable input errors. Keep matching and validation pure: no
network, model, or filesystem access in the core. Evidence offsets are Unicode
code-point indices on half-open `[start, end)` ranges; never silently use byte
offsets.

## Testing Guidelines

Add focused assertions for stable behavior. Use whitebox tests for internal
invariants and blackbox tests for public behavior. Cover empty candidates,
missing text, duplicate matches, invalid ranges, and emoji or CJK offsets.
Refresh snapshots only for intentional diagnostic output with
`moon test --update`. A located span proves textual presence, not semantic
truth.

## Commit & Pull Request Guidelines

Use imperative Conventional Commit subjects such as `feat: add span matching`
or `test: cover emoji offsets`. Commit each independently useful increment after
its checks pass. Pull requests should explain the behavior and rationale,
include exact validation commands, link an issue when applicable, and document
any public API or compatibility change.
