///|
/// Recoverable errors raised while constructing source documents.
pub(all) suberror DocumentError {
  EmptyDocumentId
}

///|
/// Construct a document with a non-blank id.
///
/// Empty text is valid: it represents a real source with no extractable
/// content. Matching against it returns `Missing` rather than inventing
/// evidence.
#warnings("-result_error_return")
pub fn Document::new(
  id : String,
  text : String,
) -> Result[Document, DocumentError] {
  if id.is_blank() {
    return Err(EmptyDocumentId)
  }
  Ok(Document::{ id, text, })
}
