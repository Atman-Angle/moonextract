# MoonExtract Future Plan Engine

This document describes a future extraction plan compiler beyond the current v0.2 LLM extraction engine. It is a design specification, not a claim that the plan compiler is implemented.

## Goal

MoonExtract turns a declarative extraction plan into a deterministic execution
plan over a source document. The output is a structured extraction result with
source evidence, transformation traces, and diagnostics. The engine does not
call a model, fetch a document, parse PDFs, or decide semantic truth.

The existing evidence core, including exact matching and Unicode code-point
spans, is a primitive used by the engine. The project's new core is the plan
compiler, execution VM, evidence propagation, and revision mapping.

## Pipeline

```text
plan JSON
  -> plan AST
  -> static validation
  -> execution IR
  -> deterministic VM
  -> extraction result
       - field values
       - evidence spans
       - transformation traces
       - diagnostics
```

A document revision can be applied to an existing result:

```text
old document + new document + extraction result
  -> revision mapping
  -> rebased evidence or explicit invalidation
```

## Plan model

An extraction plan contains:

- `fields`: named captures with one or more evidence rules.
- `anchors`: literal text or a supported pattern form that starts a capture.
- `bounds`: a delimiter, a scope end, or a bounded lookahead window.
- `scopes`: nested regions in which rules may execute.
- `repeats`: repeated blocks with a minimum and maximum count.
- `alternatives`: ordered or prioritized rule branches.
- `conflicts`: policies for duplicate fields and overlapping captures.
- `normalization`: explicit value transformations and their source mapping.

The first implementation should keep the plan language small. It should not
become a general-purpose regular expression engine.

## Compiler responsibilities

The compiler validates a plan before execution:

- every referenced field and scope exists;
- a repeat has a finite upper bound;
- required captures cannot be statically impossible;
- anchored rules cannot reference an out-of-scope position;
- overlapping rules have an explicit precedence or conflict policy;
- normalization settings are compatible with the capture type.

It then lowers the plan to a compact instruction stream. Each instruction has a
stable rule id and source-plan location so runtime diagnostics can point back to
the plan.

## Execution semantics

The VM uses a Unicode code-point cursor over the current document. Its main
operations are:

- seek an anchor from the current cursor;
- capture until a delimiter or scope boundary;
- enter and leave a scope;
- execute a repeat block;
- choose an alternative in deterministic priority order;
- stop at a bounded lookahead limit;
- record a failed rule without abandoning unrelated rules.

All candidate captures are retained until conflict resolution finishes. The VM
must never silently choose the first of several equally ranked candidates.

## Evidence and transformations

Each field result stores:

- `value`: the value returned to the caller;
- `evidence`: the verbatim source span;
- `trace`: the transformations applied to the value;
- `rule_id`: the plan rule that produced it;
- `diagnostics`: ambiguity, conflict, or recovery information.

A transformation must carry a source mapping. A trimmed value, for example, has
a smaller value interval than its evidence interval. The caller can therefore
highlight the original text even when the returned value is normalized.

## Revision mapping

For document revisions, the engine uses an edit script to map old intervals to
new intervals. A mapping has three outcomes:

- `Preserved`: the evidence still points to the same source content.
- `Changed`: the interval moved, but the mapped content can be verified.
- `Invalidated`: the edit makes the evidence unreliable.

Invalidation is a successful diagnostic, not an exception. It prevents stale
highlighting and stale extracted values.

## Diagnostics

Diagnostics use stable codes and include a plan location and document interval
where possible. Initial categories:

- `MissingRequiredField`
- `AmbiguousCapture`
- `ConflictingCapture`
- `UnreachableRule`
- `InvalidScope`
- `UnboundedRepeat`
- `EvidenceInvalidated`
- `UnsupportedPlanFeature`

## Boundaries

The first phase does not implement:

- LLM adapters or prompt management;
- OCR or PDF parsing;
- a general regex or full parser generator;
- semantic truth evaluation;
- a web UI.

Existing string matching, Unicode normalization, fuzzy search, and automata
packages may be used as dependencies or references where their licenses allow.
The engine must document each dependency and must not present those algorithms
as its own contribution.

## Acceptance targets

- A plan with two fields, one bounded repeat, and one optional field executes
  from JSON through the CLI.
- Ambiguous and missing fields produce stable diagnostics with plan locations.
- A changed document preserves or invalidates evidence without producing a
  stale span.
- Public API tests cover validation, execution, evidence mapping, and revision
  mapping.
- `moon check --target all --no-mbti`, `moon test`, and a README demo pass in CI.
