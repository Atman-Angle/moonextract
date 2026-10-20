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

## Construction and slicing

```moonbit
Document::new(id, text) -> Result[Document, DocumentError]
Span::new(start, end) -> Result[Span, SpanError]
Document::char_length() -> Int32
Document::slice(span) -> Result[String, SpanError]
```

`Document::new` rejects blank ids but accepts empty text. `slice` rejects
negative or inverted spans, and spans beyond `char_length()`.

## Matching

```moonbit
Document::find_first(candidate) -> Result[Evidence?, MatchError]
Document::find_all(candidate) -> Result[Array[Evidence], MatchError]
Document::locate(candidate) -> Result[MatchResult, MatchError]
```

Matching is exact and case-sensitive. `find_all` includes overlapping
occurrences. `locate` classifies zero matches as `Missing`, one as `Unique`, and
two or more as `Ambiguous`. An empty candidate returns `EmptyCandidate`; it is
not treated as a match.

## Extraction

```moonbit
Document::extract(field, value, normalized_value) -> Result[Extraction, ExtractionError]
Document::extract_normalized(field, value) -> Result[Extraction, ExtractionError]
normalize_whitespace(value) -> String
```

`extract` rejects blank fields and empty values. `value` and `evidence` remain
verbatim. `normalized_value` is an explicit caller decision; the convenience
constructor folds Unicode whitespace runs to one ASCII space and trims edges.
Missing and ambiguous candidates are returned as `Extraction` values with empty
or multiple evidence records respectively.

## Chunking

```moonbit
Document::chunks(max_chars) -> Result[Array[TextChunk], ChunkError]
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

Validation checks that:

- `Unique` has exactly one evidence record.
- `Ambiguous` has at least two evidence records.
- `Missing` has no evidence records.
- Every evidence record uses the source document id.
- Every span is non-empty and inside the document.
- Evidence text equals the document slice at that span.
- Evidence text equals the extraction's raw value.
- No two evidence records repeat the same span.

Validation is a textual consistency check. It does not establish semantic truth
or model confidence.

## Error handling

All recoverable input problems are explicit variants in `DocumentError`,
`SpanError`, `MatchError`, `ExtractionError`, `ChunkError`, or
`ValidationError`. Callers should handle `Missing` and `Ambiguous` as data, not
as exceptions. The core never performs network, model, OCR, PDF, or filesystem
I/O.
