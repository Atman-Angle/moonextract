///|
fn matching_test_document(
  id : String,
  text : String,
) -> @moonextract.Document raise {
  match @moonextract.Document::new(id, text) {
    Ok(document) => document
    Err(_) => fail("test document should be valid")
  }
}

///|
test "find_first locates chinese text by code point" {
  let document = matching_test_document("contract", "甲方：示例公司")
  match document.find_first("示例公司") {
    Ok(Some(evidence)) => {
      assert_eq(evidence.document_id(), "contract")
      assert_eq(evidence.span().start(), 3)
      assert_eq(evidence.span().end(), 7)
      assert_eq(evidence.text(), "示例公司")
    }
    _ => fail("expected one chinese match")
  }
}

///|
test "find_first keeps emoji spans in code points" {
  let document = matching_test_document("unicode", "A😀中B")
  match document.find_first("😀中") {
    Ok(Some(evidence)) => {
      assert_eq(evidence.span().start(), 1)
      assert_eq(evidence.span().end(), 3)
      assert_eq(evidence.text(), "😀中")
    }
    _ => fail("expected one emoji match")
  }
}

///|
test "find_first reports absent and empty candidates" {
  let document = matching_test_document("empty", "")
  match document.find_first("anything") {
    Ok(None) => ()
    _ => fail("empty document should have no match")
  }
  match document.find_first("") {
    Err(@moonextract.MatchError::EmptyCandidate) => ()
    _ => fail("empty candidate should be rejected")
  }
}

///|
test "find_all reports overlapping duplicate matches" {
  let document = matching_test_document("duplicates", "aaa")
  match document.find_all("aa") {
    Ok(matches) => {
      assert_eq(matches.length(), 2)
      assert_eq(matches[0].span().start(), 0)
      assert_eq(matches[0].span().end(), 2)
      assert_eq(matches[1].span().start(), 1)
      assert_eq(matches[1].span().end(), 3)
    }
    Err(_) => fail("duplicate search should succeed")
  }
}

///|
test "find_all preserves code-point offsets for repeated emoji text" {
  let document = matching_test_document("emoji", "😀a😀a😀")
  match document.find_all("😀a") {
    Ok(matches) => {
      assert_eq(matches.length(), 2)
      assert_eq(matches[0].span().start(), 0)
      assert_eq(matches[1].span().start(), 2)
      assert_eq(matches[1].span().end(), 4)
    }
    Err(_) => fail("emoji duplicate search should succeed")
  }
}

///|
test "find_all returns no matches without inventing evidence" {
  let document = matching_test_document("missing", "合同正文")
  match document.find_all("发票") {
    Ok(matches) => assert_eq(matches.length(), 0)
    Err(_) => fail("absent candidate must be a successful empty search")
  }
}

///|
test "find_all handles adversarial repetition in linear time" {
  let document = matching_test_document("long", String::make(20_000, 'a') + "b")
  let candidate = String::make(10_000, 'a') + "c"
  match document.find_all(candidate) {
    Ok(matches) => assert_eq(matches.length(), 0)
    Err(_) => fail("long absent candidate should be a normal outcome")
  }
}

///|
test "find_all rejects malformed utf-16 candidates" {
  let document = matching_test_document("doc", "abc")
  let malformed = String::from_array([(0xD800).unsafe_to_char(), 'a'])
  match document.find_all(malformed) {
    Err(@moonextract.MatchError::InvalidCandidate) => ()
    _ => fail("malformed candidate must be rejected")
  }
}

///|
test "locate classifies unique evidence" {
  let document = matching_test_document(
    "resume", "姓名：张三；职位：工程师",
  )
  match document.locate("张三") {
    Ok(result) => {
      match result.status() {
        @moonextract.MatchStatus::Unique => ()
        _ => fail("one occurrence must be unique")
      }
      assert_eq(result.matches().length(), 1)
    }
    Err(_) => fail("unique location should succeed")
  }
}

///|
test "locate classifies repeated evidence as ambiguous" {
  let document = matching_test_document(
    "contract", "甲方：A公司；乙方：A公司",
  )
  match document.locate("A公司") {
    Ok(result) => {
      match result.status() {
        @moonextract.MatchStatus::Ambiguous => ()
        _ => fail("duplicate text must be ambiguous")
      }
      assert_eq(result.matches().length(), 2)
      assert_eq(result.matches()[0].span().start(), 3)
      assert_eq(result.matches()[1].span().start(), 10)
    }
    Err(_) => fail("ambiguous location should still return candidates")
  }
}

///|
test "locate classifies absent text as missing" {
  let document = matching_test_document("docs", "版本 1.0")
  match document.locate("版本 2.0") {
    Ok(result) => {
      match result.status() {
        @moonextract.MatchStatus::Missing => ()
        _ => fail("absent text must be missing")
      }
      assert_eq(result.matches().length(), 0)
    }
    Err(_) => fail("absent text is a normal outcome")
  }
}
