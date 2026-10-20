# MoonExtract

MoonExtract is a traceable structured information extraction library for MoonBit.
It connects an extracted value to verbatim source evidence, Unicode character
spans, duplicate matches, and explicit ambiguity states. The first phase is
offline and model-agnostic: an LLM or other producer may supply candidate text,
while MoonExtract verifies whether that text occurs in the document.

The design is inspired by [Google LangExtract](https://github.com/google/langextract)
but is implemented independently in MoonBit under Apache-2.0.

## Status

Core evidence matching is under active development. A stable public API and CLI
will be documented as each increment lands. The project intentionally does not
claim that a located span proves the semantic truth of an extraction.

## Development

```powershell
moon fmt
moon check
moon test
moon run cmd/main
```

The repository targets MoonBit 0.10.14 or newer. See `docs/ARCHITECTURE.md` for
the module boundary and `AGENTS.md` for contributor conventions.
