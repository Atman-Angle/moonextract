///|
fn e2e_test_document(id : String, text : String) -> @moonextract.Document raise {
  match @moonextract.Document::new(id, text) {
    Ok(document) => document
    Err(_) => fail("test document should be valid")
  }
}

///|
test "end-to-end contract extraction keeps verbatim evidence" {
  let document = e2e_test_document(
    "contract-e2e", "合同编号：HT-001\n甲方：示例公司\n签署地：上海",
  )
  let extraction = match
    document.extract("party", "示例公司", "示例公司") {
    Ok(extraction) => extraction
    Err(_) => fail("extraction should succeed")
  }
  match extraction.status() {
    @moonextract.MatchStatus::Unique => ()
    _ => fail("contract party should be unique")
  }
  match @moonextract.validate_extraction(document, extraction) {
    Ok(_) => ()
    Err(_) => fail("contract extraction should validate")
  }
  let json = extraction.to_json_string()
  assert_true(json.contains("\"status\":\"unique\""))
  assert_true(json.contains("\"text\":\"示例公司\""))
}

///|
test "end-to-end resume extraction preserves ambiguity" {
  let document = e2e_test_document(
    "resume-e2e", "工作经历：A公司\n项目经历：A公司",
  )
  let extraction = match document.extract_normalized("company", "A公司") {
    Ok(extraction) => extraction
    Err(_) => fail("ambiguous extraction should succeed")
  }
  match extraction.status() {
    @moonextract.MatchStatus::Ambiguous => ()
    _ => fail("repeated company should be ambiguous")
  }
  assert_eq(extraction.evidence().length(), 2)
  match @moonextract.validate_extraction(document, extraction) {
    Ok(_) => ()
    Err(_) => fail("ambiguous extraction should still validate")
  }
}

///|
test "end-to-end technical document supports missing evidence" {
  let document = e2e_test_document(
    "manual-e2e", "版本：1.0\n接口：GET /health",
  )
  let extraction = match document.extract_normalized("version", "2.0") {
    Ok(extraction) => extraction
    Err(_) => fail("missing evidence is a normal outcome")
  }
  match extraction.status() {
    @moonextract.MatchStatus::Missing => ()
    _ => fail("version 2.0 is absent from the manual")
  }
  assert_eq(extraction.evidence().length(), 0)
  match @moonextract.validate_extraction(document, extraction) {
    Ok(_) => ()
    Err(_) => fail("missing extraction should validate structurally")
  }
  let json = extraction.to_json_string()
  assert_true(json.contains("\"status\":\"missing\""))
  assert_true(json.contains("\"evidence\":[]"))
}

///|
test "end-to-end chunk mapping agrees with document globals" {
  let document = e2e_test_document(
    "emoji-e2e", "说明😀：甲方向乙方付款",
  )
  let chunks = match document.chunks(4) {
    Ok(chunks) => chunks
    Err(_) => fail("chunking should succeed")
  }
  let mut found = false
  for index = 0; index < chunks.length(); index = index + 1 {
    let chunk = chunks[index]
    let chunk_document = e2e_test_document(document.id(), chunk.text())
    match chunk_document.find_first("甲方") {
      Ok(Some(local_evidence)) => {
        let local_start = local_evidence.span().start()
        let local_end = local_evidence.span().end()
        let global = match chunk.to_global(local_start, local_end) {
          Ok(span) => span
          Err(_) => fail("local span should map")
        }
        assert_eq(global.start(), 4)
        assert_eq(global.end(), 6)
        match document.slice(global) {
          Ok(text) => assert_eq(text, "甲方")
          Err(_) => fail("global span should slice")
        }
        found = true
      }
      _ => ()
    }
  }
  assert_true(found)
}

///|
test "end-to-end json output round-trips through the core parser" {
  let document = e2e_test_document("unicode-e2e", "状态：😀通过")
  let extraction = match document.extract("status", "😀通过", "通过") {
    Ok(extraction) => extraction
    Err(_) => fail("emoji extraction should succeed")
  }
  let json = extraction.to_json_string()
  assert_eq(@json.parse(json).stringify(), json)
  assert_true(json.contains("\"start\":3"))
  assert_true(json.contains("\"end\":6"))
}
