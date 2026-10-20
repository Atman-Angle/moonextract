///|
test "document slices by unicode code point" {
  let document = @moonextract.Document::{ id: "unicode", text: "A😀中B", }
  assert_eq(document.char_length(), 4)
  let middle = document.slice(@moonextract.Span::{ start: 1, end: 3, })
  match middle {
    Ok(text) => assert_eq(text, "😀中")
    Err(_) => fail("valid unicode span was rejected")
  }
}

///|
test "document slice rejects inverted and negative spans" {
  let document = @moonextract.Document::{ id: "unicode", text: "A😀中B", }
  match document.slice(@moonextract.Span::{ start: 2, end: 1, }) {
    Err(@moonextract.SpanError::InvalidSpan(_, _)) => ()
    _ => fail("inverted span was not rejected")
  }
  match document.slice(@moonextract.Span::{ start: -1, end: 1, }) {
    Err(@moonextract.SpanError::InvalidSpan(_, _)) => ()
    _ => fail("negative span was not rejected")
  }
}

///|
test "document slice rejects out-of-bounds spans" {
  let document = @moonextract.Document::{ id: "unicode", text: "A😀中B", }
  match document.slice(@moonextract.Span::{ start: 3, end: 5, }) {
    Err(@moonextract.SpanError::SpanOutOfBounds(3, 5, 4)) => ()
    _ => fail("out-of-bounds span was not reported precisely")
  }
}

///|
test "empty document has zero code points" {
  let document = @moonextract.Document::{ id: "empty", text: "", }
  assert_eq(document.char_length(), 0)
  match document.slice(@moonextract.Span::{ start: 0, end: 0, }) {
    Ok(text) => assert_eq(text, "")
    Err(_) => fail("empty span should be valid")
  }
}

///|
test "span constructor validates ordering and sign" {
  match @moonextract.Span::new(1, 3) {
    Ok(span) => {
      assert_eq(span.start, 1)
      assert_eq(span.end, 3)
    }
    Err(_) => fail("valid span was rejected")
  }
  match @moonextract.Span::new(3, 1) {
    Err(@moonextract.SpanError::InvalidSpan(3, 1)) => ()
    _ => fail("inverted span was not rejected")
  }
  match @moonextract.Span::new(-1, 1) {
    Err(@moonextract.SpanError::InvalidSpan(-1, 1)) => ()
    _ => fail("negative span was not rejected")
  }
}
