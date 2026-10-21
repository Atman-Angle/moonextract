///|
/// Run model extraction over a document and resolve claims against the full
/// source document.
///
/// Chunks overlap so a value near a chunk boundary has surrounding context in
/// at least one model call. Claims from all chunks are deduplicated by the
/// resolver, then checked against the full document rather than against a single
/// chunk. `complete` is injected so tests and alternative providers do not need
/// network access.
#warnings("-result_error_return")
pub async fn extract_with_model(
  document : @moonextract.Document,
  fields : Array[FieldDefinition],
  complete : async (Prompt) -> Result[String, String],
  chunk_size~ : Int32 = 4000,
  overlap~ : Int32 = 400,
) -> Result[ExtractionReport, EngineError] {
  if fields.length() == 0 {
    return Err(NoFields)
  }
  let chunks = match document.chunks_with_overlap(chunk_size, overlap) {
    Ok(chunks) => chunks
    Err(_) =>
      return Err(
        InvalidChunk("chunk size and overlap must describe a non-empty window"),
      )
  }
  let claims : Array[LlmClaim] = []
  for chunk in chunks {
    let prompt = build_prompt(fields, chunk.text())
    let output = match complete(prompt) {
      Ok(output) => output
      Err(message) => return Err(ModelFailed(message))
    }
    let parsed = match parse_model_output(output) {
      Ok(parsed) => parsed
      Err(error) => return Err(error)
    }
    let source = ClaimSource::new(
      index=chunk.index(),
      start=chunk.start(),
      end=chunk.end(),
    )
    for claim in parsed {
      claims.push(claim.with_source(source))
    }
  }
  resolve_claims(document, fields, claims, chunks.length())
}
