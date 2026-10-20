# MoonExtract

MoonExtract is a pure MoonBit library for turning candidate structured values
into traceable evidence records. Given a source document and a candidate value,
it reports whether the value occurs verbatim, where every occurrence lives, and
whether the result is unique, ambiguous, or missing.

It is inspired by [Google LangExtract](https://github.com/google/langextract)
but implemented independently in MoonBit under Apache-2.0.

## Why evidence, not truth

An extraction pipeline can be wrong even when the source text is quoted
perfectly. MoonExtract therefore makes a narrow, testable promise: a successful
evidence record proves that the candidate text occurs at the reported
code-point span. It does not prove that the candidate is semantically correct.

## Features

- Verbatim evidence slices with Unicode code-point offsets.
- Unique, ambiguous, and missing match states.
- All duplicate occurrences, including overlapping matches.
- Normalized values kept separate from raw values and evidence.
- Deterministic text chunking with global-coordinate mapping.
- Structured JSON output and extraction consistency validation.
- No network, model, OCR, PDF, or filesystem dependency in the core.

## Quick start

Add the package import to `moon.pkg` once the module is published:

```moonbit
import {
  "Atman-Angle/moonextract" @moonextract,
}
```

Then build an evidence record:

```moonbit
let document = try! @moonextract.Document::new(
  "contract-1",
  "合同编号：HT-001\n甲方：示例公司",
)
let extraction = try! document.extract_normalized("party", "示例公司")
try! @moonextract.validate_extraction(document, extraction)
println(extraction.to_json_string(indent=2))
```

The core API returns `Result` values for recoverable input errors and never
silently converts a missing or multiply located candidate into successful
evidence.

## CLI demo

```powershell
moon run cmd/main
moon run cmd/main -- "备注：😀通过" "😀通过" status
```

The default demo locates two occurrences of `示例公司` in a contract and reports
`ambiguous`. The second command reports code-point span `3..6`, not UTF-16 or
UTF-8 offsets.

```json
{
  "field": "status",
  "value": "😀通过",
  "normalized_value": "😀通过",
  "status": "unique",
  "evidence": [
    {
      "document_id": "demo",
      "span": { "start": 3, "end": 6 },
      "text": "😀通过"
    }
  ]
}
```

## Offset contract

All public offsets are Unicode code-point indices into the original document and
use half-open ranges `[start, end)`. A span is valid only when
`0 <= start <= end <= document.char_length()`. Evidence spans must be non-empty.
Never mix these offsets with UTF-16 code units or UTF-8 byte offsets.

## Development

```powershell
moon fmt
moon check
moon test
moon run cmd/main
```

The repository targets MoonBit 0.10.16 or newer. See
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/API.md](docs/API.md) for
module boundaries and detailed contracts.

## Scope

The first phase is an offline, model-agnostic core. LLM adapters, prompt
management, OCR, PDF parsing, semantic validation, and a web UI are intentionally
out of scope.

## License

Apache-2.0. See [LICENSE](LICENSE).
