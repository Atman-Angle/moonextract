# Adversarial Technical Review

Date: 2026-10-21

## Review question

Does the repository now contain an independently useful extraction engine, or
is it still a thin wrapper around string matching?

## Findings and changes

### F1. Exact matching alone is not a structured extraction engine

An exact match proves textual presence, but it does not produce field values,
handle a model response, or explain why a value was selected. The new `engine`
package adds field definitions, prompt construction, claim parsing, evidence
resolution, diagnostics, and report serialization.

Status: implemented.

### F2. Reimplementing common matching or Unicode algorithms would add little

The Mooncakes registry already exposes Aho-Corasick, fuzzy search, and Unicode
normalization packages. MoonExtract reuses the deterministic evidence core and
does not claim those algorithms as new work. The independent contribution is
the model-to-evidence pipeline and its resolution policy.

Status: accepted dependency boundary.

### F3. A model value must not be used as evidence

The resolver searches for the model's `quote`, not its `value`. If the quote is
absent or context does not match, the result is `missing_source` rather than a
fabricated span. `value` and `normalized_value` remain separate from the quote.

Status: implemented and tested.

### F4. Repeated source text needs a deterministic disambiguation rule

The resolver scores every quote occurrence against nearby context occurrences,
prefers preceding context on equal distance, and retains ambiguity when multiple
occurrences still tie. A test covers two identical company names with different
contract-party contexts.

Status: implemented and tested.

### F5. Non-repeatable fields need an explicit conflict policy

Different normalized values for a non-repeatable field now produce a
`field_conflict` diagnostic and mark all affected results as `conflict`. The
engine does not silently keep the first or last value.

Status: implemented and tested.

### F6. Chunk boundaries can duplicate or split evidence

`Document::chunks_with_overlap` keeps global code-point offsets and adds a finite
overlap. Claims from all chunks are deduplicated and resolved against the full
document. The evaluation runs with small chunks, so the merge path is exercised.

Status: implemented and tested.

### F7. A wrapper claim needs an external comparison

Two data sets compare the engine with a baseline that uses only `value` and
exact matching. Current results:

- contracts: engine 9/9, baseline 4/9;
- support tickets: engine 11/11, baseline 8/11.

The fixtures are small and curated. The result demonstrates why quote and
context handling are necessary for these cases; it is not a general accuracy
claim.

Status: verified on the checked-in corpus.

### F8. Provider credentials must remain out of public APIs and logs

The OpenAI adapter reads the key from environment variables in the CLI. The
public `OpenAIConfig` no longer exposes a key getter. The mock server is used for
faithful HTTP-level tests without a real credential.

Status: implemented.

## Residual risks

- No external live model was called in this environment because no API key was
  available. The HTTP path was verified against a local OpenAI-compatible
  server, not against a production model.
- The context score is a heuristic. It is deterministic and tested, but a
  high-stakes integration may need domain-specific anchors.
- The data set is intentionally small and must not be presented as universal
  extraction accuracy.
- The plan compiler described in `PLAN_ENGINE.md` remains future work and is not
  part of the current implementation.

## Verification evidence

```powershell
moon fmt --check
moon check --target all --no-mbti --deny-warn
moon test
moon test --target native
moon run --target native cmd/eval -- datasets/contracts.json datasets/support-tickets.json
```

Observed results:

- 57 MoonBit tests passed on the default target;
- 57 MoonBit tests passed on the native target;
- both data sets reached engine accuracy 1.0 on the checked-in expected fields;
- contract and support-ticket extraction returned `diagnostics: []` through the
  local OpenAI-compatible HTTP server.
