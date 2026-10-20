///|
fn validation_test_document(
  id : String,
  text : String,
) -> @moonextract.Document raise {
  match @moonextract.Document::new(id, text) {
    Ok(document) => document
    Err(_) => fail("test document should be valid")
  }
}

///|
test "valid extraction passes consistency validation" {
  let document = validation_test_document("contract", "甲方：示例公司")
  match document.extract("party", "示例公司", "示例公司") {
    Ok(extraction) =>
      match @moonextract.validate_extraction(document, extraction) {
        Ok(_) => ()
        Err(_) => fail("consistent extraction should validate")
      }
    Err(_) => fail("extraction should succeed")
  }
}

///|
test "missing extraction validates only when the value is absent" {
  let document = validation_test_document("contract", "甲方：示例公司")
  match document.extract_normalized("party", "另一家公司") {
    Ok(extraction) =>
      match @moonextract.validate_extraction(document, extraction) {
        Ok(_) => ()
        Err(_) => fail("truly missing extraction is structurally valid")
      }
    Err(_) => fail("missing extraction should be returned")
  }
}

///|
test "ambiguous extraction validates against the full match set" {
  let document = validation_test_document("doc", "aaaa")
  match document.extract("value", "aa", "aa") {
    Ok(extraction) => {
      assert_eq(extraction.evidence().length(), 3)
      match @moonextract.validate_extraction(document, extraction) {
        Ok(_) => ()
        Err(_) => fail("complete ambiguous extraction should validate")
      }
    }
    Err(_) => fail("ambiguous extraction should be returned")
  }
}
