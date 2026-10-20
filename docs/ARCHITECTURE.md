# MoonExtract Architecture

## Outcome and boundary

MoonExtract turns a candidate extraction value into an auditable relation to a
source `Document`. It owns Unicode-safe coordinates, exact text matching,
duplicate discovery, ambiguity classification, normalized-value separation,
validation, chunk coordinate mapping, and deterministic JSON serialization.

It does not own prompting, model calls, document downloads, OCR, PDF extraction,
semantic truth evaluation, or a web UI. A match proves textual presence only.

## Core flow

`source text -> Document -> candidate text -> matching -> Evidence -> Extraction -> JSON`

Coordinates use Unicode code-point indices and half-open intervals. A match is
evidence of textual presence. Callers must keep model confidence or domain
validation as separate metadata.

## Modules

- `types.mbt`: shared document, span, evidence, match, and extraction types.
- `document.mbt`: document identity and construction rules.
- `span.mbt`: code-point length, span construction, and verbatim slicing.
- `matching.mbt`: exact first/all matching and status classification.
- `extraction.mbt`: normalized-value separation and extraction construction.
- `chunking.mbt`: deterministic chunks and local-to-global span mapping.
- `json.mbt`: stable structured JSON output.
- `validation.mbt`: evidence consistency checks against the source document.
- `cmd/main`: deterministic CLI demonstration with no network dependency.
- `docs`: architecture, API contract, and acceptance evidence.

The first phase uses the MoonBit core `String` and `Json` APIs. External packages
are added only when the standard library cannot provide a capability and the
dependency is documented with its license.

## Failure model

Invalid ranges, blank document ids, empty candidates, missing values, and
ambiguous matches are explicit outcomes. Functions must not turn an unlocated or
multiply located candidate into a successful evidence record. Empty strings are
handled deliberately and covered by tests.

Validation rejects inconsistent evidence: wrong document ids, stale evidence
text, invalid spans, duplicate spans, status/count mismatches, and values that
disagree with their evidence.

## Determinism

The core is pure with respect to its inputs. Ordering of matches follows source
position, chunking follows code-point order, and JSON object keys are emitted in
a stable order. Tests require no network, model, or filesystem access.
