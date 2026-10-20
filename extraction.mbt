///|
/// Recoverable errors raised while constructing an extraction.
pub(all) suberror ExtractionError {
  EmptyField
  EmptyValue
  InvalidCandidate
}

///|
/// Collapse Unicode whitespace runs to one ASCII space and trim both ends.
///
/// This normalized value is intentionally separate from evidence text, which
/// always remains verbatim.
pub fn normalize_whitespace(value : String) -> String {
  let chars = value.to_array()
  let output : Array[Char] = []
  let mut pending_space = false
  for index = 0; index < chars.length(); index = index + 1 {
    let char = chars[index]
    if char.is_whitespace() {
      if output.length() > 0 {
        pending_space = true
      }
    } else {
      if pending_space {
        output.push(' ')
        pending_space = false
      }
      output.push(char)
    }
  }
  String::from_array(output[:])
}

///|
/// Build an extraction and attach every matching evidence span.
///
/// `normalized_value` is caller-defined and may differ from `value`; `value`
/// and `evidence` are never rewritten.
#warnings("-result_error_return")
pub fn Document::extract(
  self : Document,
  field : String,
  value : String,
  normalized_value : String,
) -> Result[Extraction, ExtractionError] {
  if field.is_blank() {
    return Err(EmptyField)
  }
  if value.is_empty() {
    return Err(EmptyValue)
  }
  let located = match self.locate(value) {
    Ok(result) => result
    Err(_) => return Err(InvalidCandidate)
  }
  Ok(Extraction::{
    field,
    value,
    normalized_value,
    status: located.status,
    evidence: located.matches,
  })
}

///|
/// Build an extraction and derive its normalized value with whitespace folding.
#warnings("-result_error_return")
pub fn Document::extract_normalized(
  self : Document,
  field : String,
  value : String,
) -> Result[Extraction, ExtractionError] {
  self.extract(field, value, normalize_whitespace(value))
}
