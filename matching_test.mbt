///|
test "find_first locates chinese text by code point" {
  let document = @moonextract.Document::{
    id: "contract",
    text: "甲方：示例公司",
  }
  match document.find_first("示例公司") {
    Ok(Some(evidence)) => {
      assert_eq(evidence.document_id, "contract")
      assert_eq(evidence.span.start, 3)
      assert_eq(evidence.span.end, 7)
      assert_eq(evidence.text, "示例公司")
    }
    _ => fail("expected one chinese match")
  }
}

///|
test "find_first keeps emoji spans in code points" {
  let document = @moonextract.Document::{ id: "unicode", text: "A😀中B", }
  match document.find_first("😀中") {
    Ok(Some(evidence)) => {
      assert_eq(evidence.span.start, 1)
      assert_eq(evidence.span.end, 3)
      assert_eq(evidence.text, "😀中")
    }
    _ => fail("expected one emoji match")
  }
}

///|
test "find_first reports absent and empty candidates" {
  let document = @moonextract.Document::{ id: "empty", text: "", }
  match document.find_first("anything") {
    Ok(None) => ()
    _ => fail("empty document should have no match")
  }
  match document.find_first("") {
    Err(@moonextract.MatchError::EmptyCandidate) => ()
    _ => fail("empty candidate should be rejected")
  }
}
