# MoonExtract Extraction Engine

MoonExtract turns text plus field definitions into structured values with source
evidence. The engine is model-agnostic at its core. An OpenAI-compatible adapter
is included, while tests use recorded model responses.

## Pipeline

```text
document + field definitions
  -> prompt for each overlapping chunk
  -> model response with claims
  -> JSON claim parser
  -> evidence resolver
  -> conflict and missing-source diagnostics
  -> extraction report
```

## Packages

- Root package: Unicode code-point spans, exact matching, evidence validation,
  and overlapping chunks.
- `engine`: field definitions, prompts, claim parsing, evidence resolution,
  conflict handling, and model orchestration.
- `openai`: an OpenAI-compatible chat-completions adapter.
- `cmd/extract`: live extraction from a fields JSON file and a text file.
- `cmd/eval`: deterministic data-set evaluation with recorded model outputs.

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

`value` is the value stored by the caller. `quote` must be copied from the
source text. `context` is optional and is used to choose between repeated
occurrences. The engine never substitutes `value` for a missing quote.

## Resolution rules

1. Search the full document for every occurrence of `quote`.
2. If there are no occurrences, emit `missing_source`.
3. If there are multiple occurrences and no context, emit `ambiguous_source`
   and retain all evidence spans.
4. If context is supplied, score occurrences by distance to the nearest context
   occurrence, preferring a context before the quote when distances tie.
5. For a non-repeatable field, different normalized values produce a
   `field_conflict`; all affected results are marked `conflict`.
6. Identical claims from overlapping chunks are deduplicated by field, value,
   quote, and context.

## Chunking

`Document::chunks_with_overlap(max_chars, overlap_chars)` creates bounded chunks
with a configurable overlap. The model sees the chunk, but claims are resolved
against the complete document. This preserves global evidence offsets and
survives a quote that appears near or across a chunk boundary.

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
semantic truth evaluation, or UI rendering. It also does not claim that a
matched quote makes the value semantically correct.
