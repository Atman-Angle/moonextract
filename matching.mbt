///|
/// Recoverable errors raised while locating candidate text.
pub(all) suberror MatchError {
  EmptyCandidate
  InvalidCandidate
}

///|
/// Build the KMP failure table for exact code-point matching.
fn build_failure_table(needle : Array[Char]) -> Array[Int32] {
  let length = needle.length()
  let failure : Array[Int32] = []
  if length == 0 {
    return failure
  }
  failure.push(0)
  let mut prefix_length = 0
  let mut index = 1
  while index < length {
    if needle[index] == needle[prefix_length] {
      prefix_length = prefix_length + 1
      failure.push(prefix_length)
      index = index + 1
    } else if prefix_length > 0 {
      prefix_length = failure[prefix_length - 1]
    } else {
      failure.push(0)
      index = index + 1
    }
  }
  failure
}

///|
/// Return exact match start offsets in ascending order.
///
/// When `first_only` is true, scanning stops after the first match. The KMP
/// scan compares each haystack and candidate code point at most a constant
/// number of times, including overlapping matches.
fn find_match_starts(
  haystack : Array[Char],
  needle : Array[Char],
  first_only : Bool,
) -> Array[Int32] {
  let starts : Array[Int32] = []
  let hay_len = haystack.length()
  let needle_len = needle.length()
  if needle_len == 0 || needle_len > hay_len {
    return starts
  }
  let failure = build_failure_table(needle)
  let mut hay_index = 0
  let mut matched = 0
  while hay_index < hay_len {
    if haystack[hay_index] == needle[matched] {
      hay_index = hay_index + 1
      matched = matched + 1
      if matched == needle_len {
        starts.push(hay_index - needle_len)
        if first_only {
          return starts
        }
        matched = failure[matched - 1]
      }
    } else if matched > 0 {
      matched = failure[matched - 1]
    } else {
      hay_index = hay_index + 1
    }
  }
  starts
}

///|
#warnings("-result_error_return")
fn validate_candidate(candidate : String) -> Result[Array[Char], MatchError] {
  if candidate.is_empty() {
    return Err(EmptyCandidate)
  }
  if !is_well_formed_utf16(candidate) {
    return Err(InvalidCandidate)
  }
  Ok(candidate.to_array())
}

///|
/// Find the first exact code-point match of `candidate` in the document.
///
/// Returns `Ok(None)` when the text is absent. An empty or malformed candidate
/// is rejected because it cannot provide meaningful evidence.
#warnings("-result_error_return")
pub fn Document::find_first(
  self : Document,
  candidate : String,
) -> Result[Evidence?, MatchError] {
  let needle = match validate_candidate(candidate) {
    Ok(needle) => needle
    Err(error) => return Err(error)
  }
  let starts = find_match_starts(self.chars, needle, true)
  if starts.length() == 0 {
    return Ok(None)
  }
  let start = starts[0]
  let end = start + needle.length()
  Ok(
    Some(Evidence::{
      document_id: self.id,
      span: { start, end, },
      text: String::from_array(self.chars[start:end]),
    }),
  )
}

///|
/// Find every exact occurrence of `candidate`, including overlapping matches.
#warnings("-result_error_return")
pub fn Document::find_all(
  self : Document,
  candidate : String,
) -> Result[Array[Evidence], MatchError] {
  let needle = match validate_candidate(candidate) {
    Ok(needle) => needle
    Err(error) => return Err(error)
  }
  let starts = find_match_starts(self.chars, needle, false)
  let matches : Array[Evidence] = []
  for index = 0; index < starts.length(); index = index + 1 {
    let start = starts[index]
    let end = start + needle.length()
    matches.push(Evidence::{
      document_id: self.id,
      span: { start, end, },
      text: String::from_array(self.chars[start:end]),
    })
  }
  Ok(matches)
}

///|
/// Locate a candidate and classify whether evidence is unique, ambiguous, or absent.
#warnings("-result_error_return")
pub fn Document::locate(
  self : Document,
  candidate : String,
) -> Result[MatchResult, MatchError] {
  let matches = match self.find_all(candidate) {
    Ok(found) => found
    Err(error) => return Err(error)
  }
  let status = if matches.length() == 0 {
    Missing
  } else if matches.length() == 1 {
    Unique
  } else {
    Ambiguous
  }
  Ok(MatchResult::{ status, matches, })
}
