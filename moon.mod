// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "Atman-Angle/moonextract"

version = "0.2.0"

readme = "README.md"

repository = "https://github.com/Atman-Angle/moonextract"

license = "Apache-2.0"

keywords = [
  "extraction",
  "evidence",
  "grounding",
  "llm",
  "openai",
  "structured-extraction",
  "unicode",
]

preferred_target = "wasm"

description = "Evidence-grounded LLM structured extraction for MoonBit"

import {
  "gaato/openai@0.6.0",
  "gaato/http-async@0.4.2",
  "gaato/http@0.4.1",
  "moonbitlang/async@0.22.5",
}
