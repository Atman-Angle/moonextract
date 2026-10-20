///|
/// Recoverable errors raised when extraction data disagrees with its source.
pub(all) suberror ValidationError {
  EmptyField
  EmptyValue
  InvalidValue
  StatusMismatch(MatchStatus, MatchStatus)
  StatusEvidenceCountMismatch(Int32, Int32)
  WrongDocumentId(Int32, String, String)
  InvalidEvidenceSpan(Int32, Int32, Int32)
  EvidenceSpanMismatch(Int32, Int32, Int32, Int32, Int32)
  EvidenceTextMismatch(Int32, String, String)
  DuplicateEvidenceSpan(Int32, Int32)
  ValueEvidenceMismatch(String, String)
}

///|
/// Check that an extraction is internally consistent with its document.
///
/// Validation recomputes the complete expected match set from the source
/// document, then compares status, count, document id, span, verbatim text,
/// and source order. It proves textual support only; it never promotes a
/// located span to a semantic truth claim.
#warnings("-result_error_return")
pub fn validate_extraction(
  document : Document,
  extraction : Extraction,
) -> Result[Unit, ValidationError] {
  if extraction.field.is_blank() {
    return Err(EmptyField)
  }
  if extraction.value.is_empty() {
    return Err(EmptyValue)
  }
  let located = match document.locate(extraction.value) {
    Ok(result) => result
    Err(MatchError::InvalidCandidate) => return Err(InvalidValue)
    Err(MatchError::EmptyCandidate) => return Err(EmptyValue)
  }
  let expected_count = located.matches.length()
  let actual_count = extraction.evidence.length()
  if extraction.status != located.status {
    return Err(StatusMismatch(located.status, extraction.status))
  }
  if actual_count != expected_count {
    return Err(StatusEvidenceCountMismatch(expected_count, actual_count))
  }
  let seen : Map[(Int32, Int32), Unit] = Map([])
  for index = 0; index < actual_count; index = index + 1 {
    let evidence = extraction.evidence[index]
    let expected = located.matches[index]
    if evidence.document_id != document.id {
      return Err(WrongDocumentId(index, document.id, evidence.document_id))
    }
    let span = evidence.span
    if span.start < 0 ||
      span.end <= span.start ||
      span.end > document.char_length() {
      return Err(InvalidEvidenceSpan(index, span.start, span.end))
    }
    let key = (span.start, span.end)
    if seen.contains(key) {
      return Err(DuplicateEvidenceSpan(span.start, span.end))
    }
    seen.set(key, ())
    let expected_span = expected.span
    if span.start != expected_span.start || span.end != expected_span.end {
      return Err(
        EvidenceSpanMismatch(
          index,
          expected_span.start,
          expected_span.end,
          span.start,
          span.end,
        ),
      )
    }
    if evidence.text != expected.text {
      return Err(EvidenceTextMismatch(index, expected.text, evidence.text))
    }
    if evidence.text != extraction.value {
      return Err(ValueEvidenceMismatch(extraction.value, evidence.text))
    }
  }
  Ok(())
}
