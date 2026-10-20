///|
/// Recoverable errors raised when extraction data disagrees with its source.
pub(all) suberror ValidationError {
  WrongDocumentId(Int32, String, String)
  InvalidEvidenceSpan(Int32, Int32, Int32)
  EvidenceTextMismatch(Int32, String, String)
  StatusEvidenceCountMismatch(Int32, Int32)
  DuplicateEvidenceSpan(Int32, Int32)
  ValueEvidenceMismatch(String, String)
}

///|
/// Check that an extraction is internally consistent with its document.
///
/// Validation proves textual support only; it never promotes a located span to
/// a semantic truth claim.
#warnings("-result_error_return")
pub fn validate_extraction(
  document : Document,
  extraction : Extraction,
) -> Result[Unit, ValidationError] {
  let count = extraction.evidence.length()
  let count_valid = match extraction.status {
    Unique => count == 1
    Ambiguous => count >= 2
    Missing => count == 0
  }
  if !count_valid {
    let expected = match extraction.status {
      Unique => 1
      Ambiguous => 2
      Missing => 0
    }
    return Err(StatusEvidenceCountMismatch(expected, count))
  }
  let length = document.char_length()
  for index = 0; index < count; index = index + 1 {
    let evidence = extraction.evidence[index]
    if evidence.document_id != document.id {
      return Err(WrongDocumentId(index, document.id, evidence.document_id))
    }
    let span = evidence.span
    if span.start < 0 || span.end <= span.start || span.end > length {
      return Err(InvalidEvidenceSpan(index, span.start, span.end))
    }
    let verbatim = match document.slice(span) {
      Ok(text) => text
      Err(_) => return Err(InvalidEvidenceSpan(index, span.start, span.end))
    }
    if evidence.text != verbatim {
      return Err(EvidenceTextMismatch(index, verbatim, evidence.text))
    }
    if evidence.text != extraction.value {
      return Err(ValueEvidenceMismatch(extraction.value, evidence.text))
    }
    for earlier = 0; earlier < index; earlier = earlier + 1 {
      let previous = extraction.evidence[earlier].span
      if previous.start == span.start && previous.end == span.end {
        return Err(DuplicateEvidenceSpan(previous.start, previous.end))
      }
    }
  }
  Ok(())
}
