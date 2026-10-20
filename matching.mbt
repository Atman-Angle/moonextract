///|
/// Recoverable errors raised while locating candidate text.
pub(all) suberror MatchError {
  EmptyCandidate
}

///|
/// Find the first exact code-point match of `candidate` in the document.
///
/// Returns `Ok(None)` when the text is absent. An empty candidate is rejected
/// because it cannot provide meaningful evidence.
#warnings("-result_error_return")
pub fn Document::find_first(
  self : Document,
  candidate : String,
) -> Result[Evidence?, MatchError] {
  if candidate.is_empty() {
    return Err(EmptyCandidate)
  }
  let haystack = self.text.to_array()
  let needle = candidate.to_array()
  let hay_len = haystack.length()
  let needle_len = needle.length()
  if needle_len > hay_len {
    return Ok(None)
  }
  for start = 0; start <= hay_len - needle_len; start = start + 1 {
    let mut matched = true
    for offset = 0; offset < needle_len; offset = offset + 1 {
      if haystack[start + offset] != needle[offset] {
        matched = false
        break
      }
    }
    if matched {
      let end = start + needle_len
      return Ok(
        Some(Evidence::{
          document_id: self.id,
          span: { start, end, },
          text: String::from_array(haystack[start:end]),
        }),
      )
    }
  }
  Ok(None)
}
