# MoonExtract API Contract

## Data model

| Type | Purpose |
| --- | --- |
| `Document` | Source text with a stable non-blank `id`. Empty text is allowed. |
| `Span` | Ordered half-open code-point range `[start, end)`. |
| `Evidence` | Document id, span, and verbatim text from that span. |
| `MatchStatus` | `Unique`, `Ambiguous`, or `Missing`. |
| `MatchResult` | Status plus every matching evidence record. |
| `Extraction` | Field, raw value, normalized value, status, and evidence. |
| `TextChunk` | A deterministic code-point range with global offsets. |

All core struct fields are private. Values must be created through the
constructors below or through matching, extraction, and chunking APIs. This
keeps document ids, spans, evidence, and extraction metadata consistent by
construction. There is no public unchecked constructor.

## Construction and slicing

```moonbit
Document::new(id, text) -> Result[Document, DocumentError]
Document::id() -> String
Document::text() -> String
Document::char_length() -> Int32
Document::slice(span) -> Result[String, SpanError]

Span::new(start, end) -> Result[Span, SpanError]
Span::start() -> Int32
Span::end() -> Int32
```

`Document::new` rejects blank ids and malformed UTF-16 text, but accepts empty
text. `Span::new` rejects negative or inverted spans. `slice` rejects spans
beyond `char_length()`. Offsets are always Unicode code-point indices.

## Matching

```moonbit
Document::find_first(candidate) -> Result[Evidence?, MatchError]
Document::find_all(candidate) -> Result[Array[Evidence], MatchError]
Document::locate(candidate) -> Result[MatchResult, MatchError]

Evidence::document_id() -> String
Evidence::span() -> Span
Evidence::text() -> String
MatchResult::status() -> MatchStatus
MatchResult::matches() -> ArrayView[Evidence]
```

Matching is exact and case-sensitive. `find_all` includes overlapping
occurrences and uses a linear-time KMP scan. `locate` classifies zero matches as
`Missing`, one as `Unique`, and two or more as `Ambiguous`. Empty or malformed
UTF-16 candidates return an explicit `MatchError`.

## Extraction

```moonbit
Document::extract(field, value, normalized_value) -> Result[Extraction, ExtractionError]
Document::extract_normalized(field, value) -> Result[Extraction, ExtractionError]
normalize_whitespace(value) -> String

Extraction::field() -> String
Extraction::value() -> String
Extraction::normalized_value() -> String
Extraction::status() -> MatchStatus
Extraction::evidence() -> ArrayView[Evidence]
```

`extract` rejects blank fields and empty values. `value` and `evidence` remain
verbatim. `normalized_value` is an explicit caller decision; the convenience
constructor folds Unicode whitespace runs to one ASCII space and trims edges.
Missing and ambiguous candidates are returned as `Extraction` values with empty
or multiple evidence records respectively. Evidence is exposed as a read-only
view.

## Chunking

```moonbit
Document::chunks(max_chars) -> Result[Array[TextChunk], ChunkError]
TextChunk::index() -> Int32
TextChunk::start() -> Int32
TextChunk::end() -> Int32
TextChunk::text() -> String
TextChunk::to_global(local_start, local_end) -> Result[Span, ChunkError]
```

Chunks contain at most `max_chars` code points. Each chunk keeps document-global
`start` and `end` offsets. `to_global` rejects local spans outside the chunk.

## JSON

```moonbit
Extraction::to_json() -> Json
Extraction::to_json_string(indent? : Int32) -> String
```

The shape is stable and deterministic:

```json
{
  "field": "party",
  "value": "示例公司",
  "normalized_value": "示例公司",
  "status": "unique",
  "evidence": [
    {
      "document_id": "contract-1",
      "span": { "start": 3, "end": 7 },
      "text": "示例公司"
    }
  ]
}
```

`status` is one of `"unique"`, `"ambiguous"`, or `"missing"`. Evidence text is
always the verbatim document slice.

## Validation

```moonbit
validate_extraction(document, extraction) -> Result[Unit, ValidationError]
```

Validation recomputes the complete expected match set with
`document.locate(extraction.value)` and checks that:

- Field is non-blank and value is non-empty.
- Status equals the recomputed status.
- Evidence count equals the complete match count.
- Every evidence record uses the source document id.
- Every span is non-empty and inside the document.
- Every span equals the expected span at the same source-order position.
- Evidence text equals the expected verbatim text and the extraction's raw value.
- No two evidence records repeat the same span.

Validation is a textual consistency check. It does not establish semantic truth
or model confidence. A stale `Unique` or `Missing` result cannot pass merely
because the evidence it happens to contain is locally valid.

## Error handling

All recoverable input problems are explicit variants in `DocumentError`,
`SpanError`, `MatchError`, `ExtractionError`, `ChunkError`, or
`ValidationError`. Callers should handle `Missing` and `Ambiguous` as data, not
as exceptions. The core never performs network, model, OCR, PDF, or filesystem
I/O.