///|
fn json_test_document(
  id : String,
  text : String,
) -> @moonextract.Document raise {
  match @moonextract.Document::new(id, text) {
    Ok(document) => document
    Err(_) => fail("test document should be valid")
  }
}

///|
test "extraction serializes deterministic structured json" {
  let document = json_test_document("contract", "甲方：示例 公司")
  match document.extract("party", "示例 公司", "示例公司") {
    Ok(extraction) => {
      let json = extraction.to_json_string()
      assert_eq(
        json, "{\"field\":\"party\",\"value\":\"示例 公司\",\"normalized_value\":\"示例公司\",\"status\":\"unique\",\"evidence\":[{\"document_id\":\"contract\",\"span\":{\"start\":3,\"end\":8},\"text\":\"示例 公司\"}]}",
      )
    }
    Err(_) => fail("valid extraction should serialize")
  }
}

///|
test "json encodes ambiguous and missing statuses explicitly" {
  let document = json_test_document("resume", "A公司 A公司")
  match document.extract_normalized("company", "A公司") {
    Ok(extraction) => {
      let json = extraction.to_json_string()
      assert_true(json.contains("\"status\":\"ambiguous\""))
      assert_true(json.contains("\"text\":\"A公司\""))
    }
    Err(_) => fail("ambiguous extraction should serialize")
  }
  match document.extract_normalized("company", "B公司") {
    Ok(extraction) => {
      let json = extraction.to_json_string()
      assert_true(json.contains("\"status\":\"missing\""))
      assert_true(json.contains("\"evidence\":[]"))
    }
    Err(_) => fail("missing extraction should serialize")
  }
}

///|
test "json output escapes unicode evidence as valid json" {
  let document = json_test_document("unicode", "备注：😀通过")
  match document.extract("status", "😀通过", "通过") {
    Ok(extraction) => {
      let json = extraction.to_json_string()
      let parsed = @json.parse(json)
      let roundtrip = parsed.stringify()
      assert_eq(roundtrip, json)
    }
    Err(_) => fail("emoji extraction should serialize")
  }
}
