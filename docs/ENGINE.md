# MoonExtract Extraction Engine

MoonExtract turns text plus field definitions into structured values with source
evidence. The engine is model-agnostic at its core. An OpenAI-compatible adapter
is included, while deterministic tests use recorded model claims.

## Pipeline

```text
document + field definitions
  -> overlapping chunk prompts
  -> chunk-local model claims
  -> JSON claim parser
  -> quote and value-consistency resolver
  -> conflict and missing-source diagnostics
  -> extraction report
```

## Packages

- Root package: Unicode code-point spans, exact matching, evidence validation,
  and overlapping chunks.
- `engine`: field definitions, prompts, claim parsing, evidence resolution,
  context handling, conflict handling, and model orchestration.
- `openai`: an OpenAI-compatible chat-completions adapter.
- `cmd/extract`: live extraction from a fields JSON file and a text file.
- `cmd/eval`: deterministic data-set evaluation with chunk-aware recorded claims.

## Field definitions

A field declares:

- `name` and model-facing `description`;
- whether it is required;
- whether it is repeatable;
- `value_kind`, currently `text` or `number`.

`number` enables a narrow normalization used for consistency checks. It accepts
ASCII digits, a leading sign, one decimal point, thousands separators,
whitespace, and common currency or duration decorations such as `元`, `￥`, and
`日`. Other text is rejected instead of being silently parsed as a number.

## Claim contract

Each model claim contains:

```json
{
  "field": "party",
  "value": "上海晨星科技有限公司",
  "quote": "上海晨星科技有限公司",
  "context": "甲方"
}
```

`value` is the stored value. `quote` must be copied from the source text. The
engine also attaches the source chunk index and global chunk range before
resolution. `context` is optional and is used to choose between repeated
occurrences. The engine never substitutes `value` for a missing quote.

## Resolution rules

1. Find every occurrence of `quote` in the full document.
2. If the claim has source-chunk metadata, retain only occurrences fully inside
   that chunk. A quote found only outside its source chunk becomes
   `source_outside_chunk`.
3. If there are no occurrences, emit `missing_source`.
4. If there are multiple occurrences and no context, emit `ambiguous_source`
   and retain all evidence spans.
5. If context is supplied, score occurrences by distance to the nearest context
   occurrence, preferring a context before the quote when distances tie.
6. For a non-repeatable field, different normalized values produce a
   `field_conflict`; all affected results are marked `conflict`.
7. Deduplicate claims after resolution when field, value, quote, status, and
   global evidence spans are identical. Overlap alone is not treated as a new
   extraction.

## Value consistency

Evidence resolution and value verification are separate:

- `verified`: the value matches the quote under the field's value policy;
- `unverified`: the quote exists, but the relation cannot be proven;
- `mismatch`: both sides are numeric and normalize to different values.

A text field whose value differs from its quote is returned with evidence and
`unverified`; the engine does not call it reliable. A numeric mismatch remains
visible with a `value_mismatch` diagnostic. This is why `resolved` means
"source evidence resolved", not "semantic truth established".

## Chunking

`Document::chunks_with_overlap(max_chars, overlap_chars)` creates bounded chunks
with a configurable overlap. Every claim carries its chunk index and global
`[start, end)` bounds. The quote must occur inside that chunk, which prevents a
global duplicate from being rebound to a different location. Claims are resolved
against the complete document only after this source restriction.

## Provider injection

`engine.extract_with_model` accepts an async completion callback. The core has
no HTTP dependency, which makes deterministic testing possible. `openai.complete`
constructs the real provider client with `gaato/openai` and
`gaato/http-async`. Authentication comes from environment variables in the CLI;
keys are never written to the repository.

## Error handling

Recoverable parsing and resolution outcomes are represented as diagnostics in
`ExtractionReport`. Invalid input, malformed model JSON, provider failure, and
invalid chunk configuration are returned as `EngineError`.

## Boundaries

The engine does not perform OCR, PDF parsing, model training, prompt management,
semantic truth evaluation, or UI rendering. It also does not convert an
`unverified` text value into a semantic claim.
