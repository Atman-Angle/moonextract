///|
test "document and span expose stable fields" {
  let document = @moonextract.Document::{
    id: "contract-1",
    text: "甲方：示例公司",
  }
  assert_eq(document.id, "contract-1")
  assert_eq(document.text, "甲方：示例公司")
  let span = @moonextract.Span::{ start: 3, end: 7, }
  assert_eq(span.start, 3)
  assert_eq(span.end, 7)
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
