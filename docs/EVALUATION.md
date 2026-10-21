# Evaluation

This report is produced from the checked-in data sets with recorded model
claims. The evaluation model is chunk-aware: it receives each overlapping chunk
prompt and emits only claims whose quote and optional context occur in that
chunk's `DOCUMENT` section. Claims marked `emit_regardless` are used only to test
missing-source behavior. The model callback is deterministic, so results are
reproducible without an API key. The same engine, parser, resolver, and merge
path are used by live model calls.

## Data sets

| Scenario | Cases | Expected fields | What is exercised |
| --- | ---: | ---: | --- |
| Contracts | 6 | 14 | normalized amount, context disambiguation, duplicate source, field conflict, unknown field, numeric mismatch, missing required field |
| Support tickets | 4 | 13, 12 with evidence | text-value uncertainty, severity conflict, missing source, chunk merging, missing required field |

The source documents, claims, expected field results, expected diagnostics, and
manually labeled evidence spans are in `datasets/contracts.json` and
`datasets/support-tickets.json`. Expected spans are code-point ranges, not values
recovered from the engine.

## Baseline input rules

The baseline is deliberately weaker than MoonExtract. It is allowed to use only:

- the field name;
- the model's `value`;
- the source document.

It is not allowed to use the model's `quote`, `context`, source-chunk metadata,
conflict policy, or evidence spans. It calls `Document::extract_normalized` and
accepts a result only when the exact value and expected status/evidence agree.
This makes the comparison explicit rather than silently giving the baseline
engine features it does not have.

## Reproduction

```powershell
moon run --target native cmd/eval -- datasets/contracts.json datasets/support-tickets.json
```

## Results

| Scenario | Engine value | Engine evidence | Baseline value | Baseline evidence |
| --- | ---: | ---: | ---: | ---: |
| Contracts | 14/14 | 14/14 | 7/14 | 7/14 |
| Support tickets | 13/13 | 12/12 | 10/13 | 9/12 |

Additional checks:

| Scenario | False positives | False negatives | Ambiguity expected/detected | Conflict expected/detected | Missing expected/detected | Diagnostics expected/detected |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Contracts | 0 | 0 | 1/1 | 2/2 | 0/0 | 5/5 |
| Support tickets | 0 | 0 | 0/0 | 2/2 | 1/1 | 4/4 |

Emitted chunk claims and merge activity:

| Scenario | Chunk-local claims emitted | Chunks evaluated |
| --- | ---: | ---: |
| Contracts | 18 | 11 |
| Support tickets | 14 | 5 |

The emitted count is larger than the expected field count in cases with
overlapping chunks. That is intentional: the resolver must deduplicate claims
that resolve to the same global evidence while preserving distinct values and
conflicts.

## Relevant negative cases

- `contract-b`: two different non-repeatable amount values produce a conflict.
- `contract-c`: repeated `晨星` without context produces ambiguous source and
  two evidence spans.
- `contract-d`: an unknown field is diagnosed and does not create a field result.
- `contract-e`: a numeric value and quote normalize differently and produce
  `value_mismatch`, not a reliable value.
- `contract-f`: a required amount is missing and produces
  `missing_required_field`.
- `ticket-a`: a text value differs from its quote and remains `unverified`.
- `ticket-b`: two severity values conflict.
- `ticket-c`: a model quote that is absent from the document produces
  `missing_source`.
- `ticket-e`: a required root cause is not extracted.

## Limits

This is a small curated corpus. The numbers demonstrate behavior on the
checked-in fixtures, not general extraction accuracy. The deterministic model
is a test double, not a production LLM. A live external model still needs a
configured provider and API key, and a larger held-out corpus before making
claims about production quality.
