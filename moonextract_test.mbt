///|
test "document and span expose stable read-only accessors" {
  let document = match
    @moonextract.Document::new("contract-1", "甲方：示例公司") {
    Ok(document) => document
    Err(_) => fail("test document should be valid")
  }
  assert_eq(document.id(), "contract-1")
  assert_eq(document.text(), "甲方：示例公司")
  let span = match @moonextract.Span::new(3, 7) {
    Ok(span) => span
    Err(_) => fail("test span should be valid")
  }
  assert_eq(span.start(), 3)
  assert_eq(span.end(), 7)
}

///|
test "match status distinguishes all outcomes" {
  let statuses : Array[@moonextract.MatchStatus] = [
    @moonextract.MatchStatus::Unique,
    @moonextract.MatchStatus::Ambiguous,
    @moonextract.MatchStatus::Missing,
  ]
  match statuses[1] {
    @moonextract.MatchStatus::Ambiguous => ()
    _ => fail("ambiguous status was not preserved")
  }
}
