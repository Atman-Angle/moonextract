# MoonExtract

[![CI](https://github.com/Atman-Angle/moonextract/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Atman-Angle/moonextract/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

MoonExtract is a pure MoonBit library for binding candidate extraction values to
verbatim source evidence. Given a source document and a candidate value, it
finds every exact occurrence, reports Unicode code-point spans, and classifies
the result as `unique`, `ambiguous`, or `missing`.

The core has no network, model, OCR, PDF, or filesystem dependency. It can be
used by RAG pipelines, document review tools, IDE integrations, and any MoonBit
application that needs to highlight or audit extracted text.

> A matched span proves textual presence. It does not prove semantic truth.

## Why evidence, not truth

An extraction pipeline can quote the wrong sentence, repeat a value from an
earlier section, or keep a stale span after the document changes. MoonExtract
keeps the contract narrow and testable:

- Evidence is always sliced verbatim from the source document.
- Every occurrence is returned, including overlapping matches.
- Multiple occurrences are reported as `ambiguous`, never silently reduced to
  one result.
- Validation recomputes the complete match set instead of trusting a supplied
  status or partial evidence.
- Raw values stay separate from normalized values.

This makes the result useful for review and audit without claiming that the
candidate is semantically correct.

## Features

- Unicode code-point indices with half-open `[start, end)` spans.
- Well-formed UTF-16 validation at document construction.
- Linear-time KMP matching for exact searches.
- `unique`, `ambiguous`, and `missing` as explicit result states.
- Private structural invariants and read-only collection accessors.
- Deterministic text chunks with local-to-global coordinate mapping.
- Stable JSON serialization for extractions and evidence.
- End-to-end validation of status, count, document id, span, text, and order.
- A small CLI demo for checking behavior from the command line.

## Quick start

The module is named `Atman-Angle/moonextract`. After the first registry release,
it can be added with:

```powershell
moon add Atman-Angle/moonextract
```

To use the current checkout as a dependency, add the package import to
`moon.pkg`:

```moonbit
import {
  "Atman-Angle/moonextract" @moonextract,
}
```

Build and validate an extraction:

```moonbit
let document = try! @moonextract.Document::new(
  "contract-1",
  "合同编号：HT-001\n甲方：示例公司",
)
let extraction = try! document.extract_normalized("party", "示例公司")
try! @moonextract.validate_extraction(document, extraction)
println(extraction.to_json_string(indent=2))
```

The API returns `Result` for recoverable input errors. Missing and ambiguous
matches remain data, not exceptions.

## API at a glance

| API | Purpose |
| --- | --- |
| `Document::new(id, text)` | Validate the document id and text, then cache code points. |
| `Document::find_first(candidate)` | Return the first exact evidence match. |
| `Document::find_all(candidate)` | Return every exact match, including overlaps. |
| `Document::locate(candidate)` | Classify a candidate as `unique`, `ambiguous`, or `missing`. |
| `Document::extract(field, value, normalized)` | Build an extraction with evidence. |
| `Document::extract_normalized(field, value)` | Use whitespace folding for the normalized value. |
| `Document::chunks(max_chars)` | Split text into deterministic code-point chunks. |
| `TextChunk::to_global(local_start, local_end)` | Map a chunk-local span to document coordinates. |
| `Extraction::to_json_string(indent?)` | Serialize an extraction deterministically. |
| `validate_extraction(document, extraction)` | Recompute and verify all evidence. |

## CLI demo

```powershell
moon run cmd/main
moon run cmd/main -- "备注：😀通过" "😀通过" status
```

The default demo finds two occurrences of `示例公司` and reports `ambiguous`.
Invalid arguments print an error and exit with code 1. The second command
reports code-point span `3..6`, not UTF-16 or UTF-8 offsets.

```json
{
  "field": "status",
  "value": "😀通过",
  "normalized_value": "😀通过",
  "status": "unique",
  "evidence": [
    {
      "document_id": "demo",
      "span": { "start": 3, "end": 6 },
      "text": "😀通过"
    }
  ]
}
```

## Contracts

### Span coordinates

All public offsets are Unicode code-point indices into the original document.
They use half-open ranges `[start, end)`. A span is valid only when
`0 <= start <= end <= document.char_length()`. Evidence spans are non-empty.
Do not mix these offsets with UTF-16 code units or UTF-8 byte offsets.

### Validation

`validate_extraction` locates the value again and compares the complete expected
match set with the supplied extraction. It rejects:

- an incorrect `unique`, `ambiguous`, or `missing` status;
- a missing or extra evidence record;
- a foreign document id;
- an invalid, reordered, or duplicate span;
- text that differs from the source slice or the extraction value.

Validation is a textual consistency check, not a semantic or model-confidence
check.

### Determinism

Matches follow source order, chunking follows code-point order, and JSON object
keys are emitted in a stable order. The core is pure with respect to its inputs.

## Scope

The first phase is an offline, model-agnostic core. The following are explicitly
out of scope:

- LLM adapters and prompt management;
- OCR and PDF parsing;
- fuzzy, semantic, or vector matching;
- semantic truth evaluation;
- a web UI or visualization layer.

Those features can be built as adapters on top of MoonExtract without changing
the evidence model.

## Development

Run these commands from the repository root in PowerShell 7:

```powershell
moon fmt
moon check
moon test
moon run cmd/main
moon check --target all --no-mbti
```

CI runs formatting, all-target type checking, and the full test suite on every
push and pull request. The repository targets MoonBit 0.10.16 or newer.

Enable the checked-in Git hook once per checkout:

```powershell
git config core.hooksPath .githooks
```

The hook runs `moon fmt --check`, `moon check`, and `moon test`.

## Project documents

- [Architecture](docs/ARCHITECTURE.md)
- [Public API](docs/API.md)
- [Project proposal](docs/PROJECT_PROPOSAL.md)

## Reference and license

MoonExtract is inspired by
[Google LangExtract](https://github.com/google/langextract) and implemented
independently in MoonBit. It is not a port and does not reuse LangExtract code.
The reference project is licensed under Apache-2.0.

MoonExtract is licensed under Apache-2.0. See [LICENSE](LICENSE).
