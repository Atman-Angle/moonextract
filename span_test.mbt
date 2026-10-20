///|
fn span_test_document(
  id : String,
  text : String,
) -> @moonextract.Document raise {
  match @moonextract.Document::new(id, text) {
    Ok(document) => document
    Err(_) => fail("test document should be valid")
  }
}

///|
fn span_test_span(start : Int32, end : Int32) -> @moonextract.Span raise {
  match @moonextract.Span::new(start, end) {
    Ok(span) => span
    Err(_) => fail("test span should be valid")
  }
}

///|
test "document slices by unicode code point" {
  let document = span_test_document("unicode", "A😀中B")
  assert_eq(document.char_length(), 4)
  let middle = document.slice(span_test_span(1, 3))
  match middle {
    Ok(text) => assert_eq(text, "😀中")
    Err(_) => fail("valid unicode span was rejected")
  }
}

///|
test "span constructor rejects inverted and negative spans" {
  match @moonextract.Span::new(2, 1) {
    Err(@moonextract.SpanError::InvalidSpan(2, 1)) => ()
    _ => fail("inverted span was not rejected")
  }
  match @moonextract.Span::new(-1, 1) {
    Err(@moonextract.SpanError::InvalidSpan(-1, 1)) => ()
    _ => fail("negative span was not rejected")
  }
}

///|
test "document slice rejects out-of-bounds spans" {
  let document = span_test_document("unicode", "A😀中B")
  match document.slice(span_test_span(3, 5)) {
    Err(@moonextract.SpanError::SpanOutOfBounds(3, 5, 4)) => ()
    _ => fail("out-of-bounds span was not reported precisely")
  }
}

///|
test "empty document has zero code points" {
  let document = span_test_document("empty", "")
  assert_eq(document.char_length(), 0)
  match document.slice(span_test_span(0, 0)) {
    Ok(text) => assert_eq(text, "")
    Err(_) => fail("empty span should be valid")
  }
}

///|
test "span constructor validates ordering and sign" {
  let span = span_test_span(1, 3)
  assert_eq(span.start(), 1)
  assert_eq(span.end(), 3)
  match @moonextract.Span::new(3, 1) {
    Err(@moonextract.SpanError::InvalidSpan(3, 1)) => ()
    _ => fail("inverted span was not rejected")
  }
  match @moonextract.Span::new(-1, 1) {
    Err(@moonextract.SpanError::InvalidSpan(-1, 1)) => ()
    _ => fail("negative span was not rejected")
  }
}
