# MoonExtract Contributor Guide

MoonExtract is a pure MoonBit library for locating structured extraction values
in source text. The core package must stay offline, deterministic, and reusable;
LLM adapters, OCR, PDF parsing, and web UI are out of scope for the first phase.

## Layout

- Root `.mbt` files contain the public library and blackbox/whitebox tests.
- `cmd/main/` contains the runnable demonstration CLI.
- `docs/` contains architecture, data-flow, and acceptance notes.
- `moon.mod` owns module metadata; each package keeps dependencies in `moon.pkg`.

## Development

Run `moon fmt`, `moon check`, `moon test`, and `moon run cmd/main` from the root.
Use `moon info` when public interfaces change. Commit each independently useful
feature after its checks pass. The checked-in hook in `.githooks/` can be enabled
with `git config core.hooksPath .githooks`.

## MoonBit conventions

Use block separators (`///|`), explicit public APIs, and `Result` values for
recoverable input errors. Evidence offsets are Unicode code-point indices with a
half-open `[start, end)` contract; never silently convert them to byte offsets.
Keep matching and validation pure so tests need no network, model, or filesystem.
Prefer assertions for stable behavior and snapshot tests only for intentional
diagnostic output.

## Contributions

Use imperative Conventional Commit subjects such as `feat: add span matching`
or `test: cover emoji offsets`. Pull requests should describe the behavior,
include exact validation commands, link an issue when applicable, and document
any changed public API or compatibility boundary. Never commit secrets,
generated `_build/` output, or unverified extraction claims.
