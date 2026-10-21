# Data Sets

Each JSON file contains one business scenario:

- `fields`: model-facing field definitions, including `value_kind`;
- `cases`: documents, recorded model claims, expected field results, expected
  diagnostics, and manually labeled evidence spans.

The evaluation model is chunk-aware. It receives one overlapping chunk prompt at
a time and returns only claims whose quote and optional context occur in that
chunk's `DOCUMENT` section. `emit_regardless` is reserved for negative tests
where the model is meant to hallucinate a quote absent from the source.

The expected spans use Unicode code-point indices. `cmd/eval` runs the same
engine used by `cmd/extract` and separately runs a value-only exact-match
baseline. See `docs/EVALUATION.md` for the result table, baseline restrictions,
negative cases, and limitations.

The fixtures intentionally include normalized values, repeated source text,
conflicting fields, ambiguous sources, unknown fields, numeric mismatches,
missing required fields, and a quote absent from the document. They are test
data, not claims about production model accuracy.
