///|
test "document constructor accepts empty text with a stable id" {
  match @moonextract.Document::new("empty-source", "") {
    Ok(document) => {
      assert_eq(document.id(), "empty-source")
      assert_eq(document.text(), "")
      assert_eq(document.char_length(), 0)
    }
    Err(_) => fail("empty text is a valid document")
  }
}

///|
test "document constructor rejects blank ids" {
  match @moonextract.Document::new("   ", "content") {
    Err(@moonextract.DocumentError::EmptyDocumentId) => ()
    _ => fail("blank document id must be rejected")
  }
  match @moonextract.Document::new("", "content") {
    Err(@moonextract.DocumentError::EmptyDocumentId) => ()
    _ => fail("empty document id must be rejected")
  }
}

///|
test "document constructor rejects malformed utf-16 text" {
  let lone_leading = String::from_array([(0xD800).unsafe_to_char(), 'a'])
  match @moonextract.Document::new("bad-leading", lone_leading) {
    Err(@moonextract.DocumentError::InvalidDocumentText) => ()
    _ => fail("lone leading surrogate must be rejected")
  }
  let lone_trailing = String::from_array(['a', (0xDC00).unsafe_to_char()])
  match @moonextract.Document::new("bad-trailing", lone_trailing) {
    Err(@moonextract.DocumentError::InvalidDocumentText) => ()
    _ => fail("lone trailing surrogate must be rejected")
  }
}

///|
test "document constructor accepts a well-formed surrogate pair" {
  let emoji = String::from_array([
    (0xD83D).unsafe_to_char(),
    (0xDE00).unsafe_to_char(),
  ])
  match @moonextract.Document::new("emoji", emoji) {
    Ok(document) => assert_eq(document.char_length(), 1)
    Err(_) => fail("paired surrogates form valid UTF-16")
  }
}
