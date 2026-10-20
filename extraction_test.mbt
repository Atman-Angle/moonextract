///|
fn extraction_test_document(
  id : String,
  text : String,
) -> @moonextract.Document raise {
  match @moonextract.Document::new(id, text) {
    Ok(document) => document
    Err(_) => fail("test document should be valid")
  }
}

///|
test "extract keeps verbatim evidence separate from normalized value" {
  let document = extraction_test_document("contract", "甲方：示例 公司")
  match document.extract("party", "示例 公司", "示例公司") {
    Ok(extraction) => {
      assert_eq(extraction.field(), "party")
      assert_eq(extraction.value(), "示例 公司")
      assert_eq(extraction.normalized_value(), "示例公司")
      assert_eq(extraction.evidence().length(), 1)
      assert_eq(extraction.evidence()[0].text(), "示例 公司")
      match extraction.status() {
        @moonextract.MatchStatus::Unique => ()
        _ => fail("one occurrence must be unique")
      }
    }
    Err(_) => fail("valid extraction should succeed")
  }
}

///|
test "normalize_whitespace folds runs and trims edges" {
  assert_eq(
    @moonextract.normalize_whitespace("  张 三 \n 工程师\t"),
    "张 三 工程师",
  )
  assert_eq(@moonextract.normalize_whitespace("   "), "")
  assert_eq(@moonextract.normalize_whitespace("张三"), "张三")
}

///|
test "extract preserves ambiguity and missing states" {
  let document = extraction_test_document(
    "resume", "公司：A公司；前公司：A公司",
  )
  match document.extract_normalized("company", "A公司") {
    Ok(extraction) => {
      assert_eq(extraction.evidence().length(), 2)
      match extraction.status() {
        @moonextract.MatchStatus::Ambiguous => ()
        _ => fail("duplicate evidence must remain ambiguous")
      }
    }
    Err(_) => fail("ambiguous extraction should still be returned")
  }
  match document.extract_normalized("company", "B公司") {
    Ok(extraction) => {
      assert_eq(extraction.evidence().length(), 0)
      match extraction.status() {
        @moonextract.MatchStatus::Missing => ()
        _ => fail("absent evidence must be missing")
      }
    }
    Err(_) => fail("missing evidence is a normal extraction outcome")
  }
}

///|
test "extract rejects blank fields and empty values" {
  let document = extraction_test_document("doc", "内容")
  match document.extract(" ", "内容", "内容") {
    Err(@moonextract.ExtractionError::EmptyField) => ()
    _ => fail("blank field must be rejected")
  }
  match document.extract("body", "", "") {
    Err(@moonextract.ExtractionError::EmptyValue) => ()
    _ => fail("empty value must be rejected")
  }
}
