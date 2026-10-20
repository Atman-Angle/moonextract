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

## Invariants

Core struct fields are private. `Document::new`, `Span::new`, matching,
extraction, and chunking are the only construction paths. Public collection
accessors return `ArrayView` so callers cannot mutate evidence behind an
`Extraction` or `MatchResult`. There is no public unchecked constructor.

`Document::new` validates UTF-16 well-formedness before accepting text and caches
the document's code points. Rejected malformed input cannot later hit a
code-point operation that aborts. Document ids are non-blank.

## Modules

- `types.mbt`: private shared types plus read-only accessors.
- `document.mbt`: identity, UTF-16 validation, and document construction.
- `span.mbt`: code-point length, span construction, and verbatim slicing.
- `matching.mbt`: linear-time KMP matching and status classification.
- `extraction.mbt`: normalized-value separation and extraction construction.
- `chunking.mbt`: deterministic chunks and local-to-global span mapping.
- `json.mbt`: stable structured JSON output.
- `validation.mbt`: recomputed full-match-set consistency checks.
- `cmd/main`: deterministic CLI demonstration with non-zero error exits.
- `docs`: architecture, API contract, and acceptance evidence.

The first phase uses the MoonBit core `String` and `Json` APIs. External packages
are added only when the standard library cannot provide a capability and the
dependency is documented with its license.

## Failure model

Invalid ranges, blank document ids, malformed UTF-16, empty candidates, missing
values, and ambiguous matches are explicit outcomes. Functions must not turn an
unlocated or multiply located candidate into a successful evidence record.

Validation re-runs `document.locate(value)` and rejects any disagreement in
status, match count, document id, span, text, or source order. It checks
duplicates with a hash map, so validation is linear in the expected match set
after the one matching scan rather than repeatedly slicing the full document.

## Determinism and resource behavior

The core is pure with respect to its inputs. Ordering of matches follows source
position, chunking follows code-point order, and JSON object keys are emitted in
a stable order. Matching uses KMP, keeping worst-case candidate scans linear in
document plus candidate length. Tests require no network, model, or filesystem
access.