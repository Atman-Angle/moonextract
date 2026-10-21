# Evaluation

This report is produced from the checked-in data sets with recorded model
claims. The model callback is deterministic, so the result is reproducible
without an API key. The same engine and parser are used for live model calls.

## Data sets

| Scenario | Cases | Expected fields | What is exercised |
| --- | ---: | ---: | --- |
| Contracts | 3 | 9 | repeated parties, normalized amount, context disambiguation, field conflict, ambiguous source |
| Support tickets | 3 | 11 | normalized root cause, severity conflict, missing source, chunk merging |

The source documents and expected spans are in `datasets/contracts.json` and
`datasets/support-tickets.json`. The expected spans are manually specified
code-point ranges, not values recovered from the engine.

## Reproduction

```powershell
moon run --target native cmd/eval -- datasets/contracts.json datasets/support-tickets.json
```

## Results

| Scenario | MoonExtract correct | Baseline correct | Expected |
| --- | ---: | ---: | ---: |
| Contracts | 9 | 4 | 9 |
| Support tickets | 11 | 8 | 11 |

The baseline uses `Document::extract_normalized` with only the model's `value`.
It cannot use a verbatim `quote`, nearby context, conflict policy, or a
canonical evidence set. The engine additionally reports `diagnostics` and
`chunk_count` for each case.

Observed cases:

- `contract-a`: baseline 2/4 because `120000 元` is not the source text
  `120,000 元`, and `30 日` is ambiguous without context.
- `contract-b`: baseline 1/3 because it lacks non-repeatable field conflict
  handling.
- `contract-c`: baseline 1/2 because `晨星` occurs twice and the simple matcher
  cannot resolve the intended occurrence.
- `ticket-a`: baseline 3/4 because `TLS 证书过期` differs from the source
  text `证书过期`.
- `ticket-b`: baseline 2/4 because it lacks severity conflict handling.
- `ticket-c`: both implementations detect an absent value, but the engine also
  emits `missing_source` with the rejected quote.

## Limits

This is a small curated corpus. The numbers demonstrate the behavior of the
checked-in fixtures; they are not a claim of general extraction accuracy. A
live external model call requires a configured provider and API key. The local
OpenAI-compatible mock server verifies the HTTP adapter and JSON handling, but
it is not a substitute for measuring a particular production model.
