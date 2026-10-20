///|
/// Recoverable errors raised while constructing source documents.
pub(all) suberror DocumentError {
  EmptyDocumentId
  InvalidDocumentText
}

///|
/// Return true when all UTF-16 surrogate code units are correctly paired.
fn is_well_formed_utf16(text : String) -> Bool {
  let units = text.code_units()
  let length = units.length()
  let mut index = 0
  while index < length {
    let unit = units[index]
    if unit.is_leading_surrogate() {
      if index + 1 >= length || !units[index + 1].is_trailing_surrogate() {
        return false
      }
      index = index + 2
    } else if unit.is_trailing_surrogate() {
      return false
    } else {
      index = index + 1
    }
  }
  true
}

///|
/// Construct a document with a non-blank id and well-formed UTF-16 text.
///
/// Empty text is valid: it represents a real source with no extractable
/// content. Matching against it returns `Missing` rather than inventing
/// evidence. Malformed UTF-16 is rejected here so later code-point operations
/// cannot abort on an already accepted document.
#warnings("-result_error_return")
pub fn Document::new(
  id : String,
  text : String,
) -> Result[Document, DocumentError] {
  if id.is_blank() {
    return Err(EmptyDocumentId)
  }
  if !is_well_formed_utf16(text) {
    return Err(InvalidDocumentText)
  }
  Ok(Document::{ id, text, chars: text.to_array(), })
}
