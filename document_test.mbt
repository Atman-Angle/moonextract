///|
test "document constructor accepts empty text with a stable id" {
  match @moonextract.Document::new("empty-source", "") {
    Ok(document) => {
      assert_eq(document.id, "empty-source")
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
