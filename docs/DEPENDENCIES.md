# Dependencies and Licenses

MoonExtract itself is licensed under Apache-2.0. Dependency versions are pinned
in `moon.mod`; downloaded sources live under the ignored `.mooncakes/` directory
and are not vendored into this repository.

## Direct dependencies

| Module | Version | License | Purpose |
| --- | --- | --- | --- |
| `gaato/openai` | 0.6.0 | Apache-2.0 | OpenAI-compatible chat-completions client |
| `gaato/http` | 0.4.1 | Apache-2.0 | Sans-IO HTTP request and response types |
| `gaato/http-async` | 0.4.2 | Apache-2.0 | Native, JS, and Wasm HTTP transport over `moonbitlang/async` |
| `moonbitlang/async` | 0.22.5 | Apache-2.0 | Async runtime, native filesystem, and socket support |

## Transitive dependencies

| Module | Version | License | Note |
| --- | --- | --- | --- |
| `gaato/sdk-runtime` | 0.7.0 | Apache-2.0 | Retry, timeout, transport, and JSON runtime for `gaato/openai` |
| `moonbit-community/flate` | 0.9.0 | Apache-2.0 | Deflate, gzip, and zlib support for HTTP content decoding |
| `gaato/brotli` | 0.2.0 | Apache-2.0 | Brotli support; static dictionary data carries an MIT notice |
| `gaato/zstd` | 0.1.0 | Apache-2.0 | Zstandard support; upstream test frames carry a BSD notice |

## Provider and data notes

- API keys are read from environment variables and are not stored or logged.
- The checked-in data sets and example documents are project-authored fixtures.
- The mock OpenAI-compatible server is a project test fixture, not a model or a
  provider.
- The reference to Google LangExtract is conceptual only. No LangExtract code is
  copied into this repository.
- Live model use remains subject to the selected provider's terms and pricing.
