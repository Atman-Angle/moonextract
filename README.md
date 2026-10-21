# MoonExtract

[![CI](https://github.com/Atman-Angle/moonextract/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Atman-Angle/moonextract/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

MoonExtract is a MoonBit-native extraction engine that turns text plus field
definitions into structured values with verbatim source evidence. It works with
an OpenAI-compatible model, but the core is provider-agnostic and deterministic
tests use recorded model output.

The engine does not treat a model value as evidence. A field is accepted only
when the model also supplies a verbatim `quote` that resolves to source text.
Repeated quotes, missing quotes, conflicting values, and chunk boundaries are
reported explicitly.

> A matched span proves textual presence. It does not prove semantic truth.

## Status

The current `v0.2` alpha includes:

- field definitions and model prompt construction;
- OpenAI-compatible chat-completions adapter;
- structured claim parsing;
- evidence resolution with raw value, normalized value, quote, and spans;
- context-based disambiguation for repeated source text;
- missing-source, ambiguous-source, and non-repeatable field conflict diagnostics;
- overlapping chunk extraction and claim deduplication;
- two business data sets and a value-only exact-match baseline;
- 57 MoonBit tests and a native evaluation command.

See [Extraction Engine](docs/ENGINE.md) and [Evaluation](docs/EVALUATION.md).

## Extraction flow

```text
field definitions + document
  -> overlapping chunk prompts
  -> model claims
  -> JSON parser
  -> quote-to-evidence resolver
  -> conflict and missing-source diagnostics
  -> extraction report
```

The model response is expected to contain claims in this shape:

```json
{
  "claims": [
    {
      "field": "party",
      "value": "上海晨星科技有限公司",
      "quote": "上海晨星科技有限公司",
      "context": "甲方"
    }
  ]
}
```

`value` is the stored value. `quote` must be copied from the document. `context`
is optional and helps choose between repeated occurrences. A quote that is not
in the source becomes a `missing_source` diagnostic; the engine never replaces it
with `value`.

## Quick start

The module is named `Atman-Angle/moonextract`. After the first registry release,
it can be added with:

```powershell
moon add Atman-Angle/moonextract
```

For the current checkout, use the package import in `moon.pkg`:

```moonbit
import {
  "Atman-Angle/moonextract",
}
```

### Evidence core

The lower-level API remains available when a caller already has a candidate
value:

```moonbit
let document = try! @moonextract.Document::new(
  "contract-1",
  "合同编号：HT-001\n甲方：示例公司",
)
let extraction = try! document.extract_normalized("party", "示例公司")
try! @moonextract.validate_extraction(document, extraction)
println(extraction.to_json_string(indent=2))
```

### Live model extraction

The native CLI reads a fields JSON file and a document text file:

```powershell
$env:MOONEXTRACT_API_KEY = "<provider key>"
$env:MOONEXTRACT_MODEL = "gpt-4.1-mini"
$env:MOONEXTRACT_BASE_URL = "https://api.openai.com/v1"
moon run --target native cmd/extract -- examples/contract-fields.json examples/contract.txt
```

`OPENAI_API_KEY` is accepted as a fallback for the key. The key is read from the
environment and is never written to the repository.

### Offline end-to-end check

A local OpenAI-compatible server verifies the real HTTP transport and response
parsing without requiring an external API key:

```powershell
python scripts/mock_openai_server.py --port 18765
```

In another terminal:

```powershell
$env:MOONEXTRACT_API_KEY = "test-key"
$env:MOONEXTRACT_BASE_URL = "http://127.0.0.1:18765/v1"
$env:MOONEXTRACT_MODEL = "moonextract-mock"
moon run --target native cmd/extract -- examples/contract-fields.json examples/contract.txt
moon run --target native cmd/extract -- examples/ticket-fields.json examples/ticket.txt
```

This exercises the same OpenAI client, HTTP transport, prompt, parser, resolver,
and report path as a live provider. The mock server is a protocol fixture, not a
claim about a particular model's quality.

## Evaluation

The checked-in data sets compare MoonExtract against a baseline that uses only
the model's `value` with exact string matching:

| Scenario | Engine correct | Baseline correct | Expected |
| --- | ---: | ---: | ---: |
| Contracts | 9 | 4 | 9 |
| Support tickets | 11 | 8 | 11 |

The fixtures cover normalized values, repeated parties, context disambiguation,
field conflicts, ambiguous sources, missing sources, and chunk merging.

```powershell
moon run --target native cmd/eval -- datasets/contracts.json datasets/support-tickets.json
```

See [docs/EVALUATION.md](docs/EVALUATION.md) for the test cases, reproduction
steps, and limitations. The numbers are evidence for this curated corpus, not a
claim of general model accuracy.

## Evidence and diagnostics

Public offsets are Unicode code-point indices with half-open `[start, end)`
ranges. Evidence text is sliced from the original document. The engine rejects
recoverable input errors with `Result` and keeps model-level failures explicit.

Field results use these states:

- `resolved`: exactly one quote occurrence was selected;
- `missing_source`: the quote is absent or its context does not match;
- `ambiguous_source`: multiple quote occurrences remain after context filtering;
- `conflict`: a non-repeatable field has different normalized values.

The report also carries stable diagnostics and the number of overlapping chunks
used for extraction. A repeated claim from overlapping chunks is deduplicated by
field, value, quote, and context.

## Scope

The current first phase does not implement:

- OCR or PDF parsing;
- model training or prompt management;
- semantic truth evaluation;
- a general regex engine;
- a web UI.

The exact matcher and Unicode handling are foundation layers. The extraction
engine adds model integration, evidence resolution, context disambiguation,
conflict handling, chunk merging, and evaluation.

## Development

Run these from the repository root in PowerShell 7:

```powershell
moon fmt
moon check
moon test
moon check --target all --no-mbti
moon run --target native cmd/eval -- datasets/contracts.json datasets/support-tickets.json
```

Enable the checked-in Git hook once per checkout:

```powershell
git config core.hooksPath .githooks
```

The hook runs `moon fmt --check`, `moon check`, and `moon test`.

## Project documents

- [Extraction Engine](docs/ENGINE.md)
- [Evaluation](docs/EVALUATION.md)
- [Current evidence architecture](docs/ARCHITECTURE.md)
- [Public API](docs/API.md)
- [Data sets](datasets/README.md)
- [Dependencies and licenses](docs/DEPENDENCIES.md)

## Reference and license

MoonExtract is inspired by
[Google LangExtract](https://github.com/google/langextract) and implemented
independently in MoonBit. It is not a port and does not reuse LangExtract code.
The reference project is licensed under Apache-2.0.

MoonExtract is licensed under Apache-2.0. See [LICENSE](LICENSE).
