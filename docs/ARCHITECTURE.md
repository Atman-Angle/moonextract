# MoonExtract Architecture

## Outcome and boundary

MoonExtract turns a candidate extraction value into an auditable relation to a
source `Document`. It owns Unicode-safe coordinates, exact text matching,
duplicate discovery, ambiguity classification, validation, and deterministic
serialization. It does not own prompting, model calls, document downloads, or
semantic truth evaluation.

## Core flow

`source text -> Document -> candidate text -> candidate spans -> Evidence -> Extraction`

Coordinates use Unicode code-point indices and half-open intervals. A match is
evidence of textual presence only. Callers must keep model confidence or domain
validation as separate metadata.

## Modules

- Root package: data types, span validation, matching, normalization, and JSON.
- `cmd/main`: a small deterministic demonstration that has no network dependency.
- `docs`: design and acceptance evidence; it must not replace executable tests.

The first phase prefers the MoonBit core `String` and `Json` APIs. External
packages are added only when a capability cannot be provided by the standard
library and the dependency is documented with its license.

## Failure model

Invalid ranges, missing candidates, and ambiguous matches are explicit values.
Functions must not turn an unlocated or multiply located candidate into a
successful evidence record. Empty strings are handled deliberately and covered
by tests.
