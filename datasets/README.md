# Data Sets

Each JSON file contains one business scenario:

- `fields`: model-facing field definitions.
- `cases`: documents, recorded model claims, and manually labeled expected
  evidence spans.

The expected spans use Unicode code-point indices. `cmd/eval` runs the same
engine used by `cmd/extract` and separately runs the value-only exact-match
baseline. See `docs/EVALUATION.md` for the result table and limitations.

The fixtures intentionally include normalized values, repeated source text,
conflicting fields, ambiguous sources, and a quote that is absent from the
document. They are test data, not claims about production model accuracy.
