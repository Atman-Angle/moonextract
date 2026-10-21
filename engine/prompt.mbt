///|
/// Build a deterministic model prompt from field definitions and source text.
///
/// The prompt distinguishes the stored value from the verbatim quote. A model
/// that paraphrases the source value can still provide a usable evidence quote,
/// while an answer without a matching quote is rejected by the resolver.
pub fn build_prompt(fields : Array[FieldDefinition], text : String) -> Prompt {
  let mut schema = ""
  for field in fields {
    let required = if field.required() { "required" } else { "optional" }
    let cardinality = if field.repeatable() { "multiple" } else { "single" }
    schema = schema +
      "- " +
      field.name() +
      " (" +
      required +
      ", " +
      cardinality +
      "): " +
      field.description() +
      "\n"
  }
  let system = "You extract structured fields from a document. " +
    "Return JSON only. For every claim include field, value, quote, and optional context. " +
    "The quote must be copied verbatim from the document and must directly support the value. " +
    "If a field cannot be supported, omit the claim. Do not use outside knowledge."
  let user = "FIELDS:\n" +
    schema +
    "\nDOCUMENT:\n<<<\n" +
    text +
    "\n>>>\n\n" +
    "Return this shape exactly:\n" +
    "{\"claims\":[{\"field\":\"name\",\"value\":\"normalized value\"," +
    "\"quote\":\"verbatim source quote\",\"context\":\"optional nearby phrase\"}]}"
  Prompt::new(system~, user~)
}

///|
/// Build the provider-facing user message for a chunk.
pub fn prompt_for_chunk(
  fields : Array[FieldDefinition],
  text : String,
) -> Prompt {
  build_prompt(fields, text)
}
