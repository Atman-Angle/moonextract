///|
test "valid extraction passes consistency validation" {
  let document = @moonextract.Document::{
    id: "contract",
    text: "甲方：示例公司",
  }
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
test "missing extraction validates without evidence" {
  let document = @moonextract.Document::{
    id: "contract",
    text: "甲方：示例公司",
  }
  match document.extract_normalized("party", "另一家公司") {
    Ok(extraction) =>
      match @moonextract.validate_extraction(document, extraction) {
        Ok(_) => ()
        Err(_) => fail("missing extraction is structurally valid")
      }
    Err(_) => fail("missing extraction should be returned")
  }
}

///|
test "validation rejects evidence from another document" {
  let document = @moonextract.Document::{
    id: "contract",
    text: "示例公司",
  }
  let extraction = @moonextract.Extraction::{
    field: "party",
    value: "示例公司",
    normalized_value: "示例公司",
    status: @moonextract.MatchStatus::Unique,
    evidence: [
      @moonextract.Evidence::{
        document_id: "other",
        span: @moonextract.Span::{ start: 0, end: 4, },
        text: "示例公司",
      },
    ],
  }
  match @moonextract.validate_extraction(document, extraction) {
    Err(@moonextract.ValidationError::WrongDocumentId(0, "contract", "other")) =>
      ()
    _ => fail("foreign evidence must be rejected")
  }
}

///|
test "validation rejects stale evidence text and overlong spans" {
  let document = @moonextract.Document::{
    id: "contract",
    text: "示例公司",
  }
  let stale = @moonextract.Extraction::{
    field: "party",
    value: "示例公司",
    normalized_value: "示例公司",
    status: @moonextract.MatchStatus::Unique,
    evidence: [
      @moonextract.Evidence::{
        document_id: "contract",
        span: @moonextract.Span::{ start: 0, end: 4, },
        text: "别的公司",
      },
    ],
  }
  match @moonextract.validate_extraction(document, stale) {
    Err(@moonextract.ValidationError::EvidenceTextMismatch(0, _, _)) => ()
    _ => fail("stale evidence text must be rejected")
  }
  let overlong = @moonextract.Extraction::{
    field: "party",
    value: "示例公司",
    normalized_value: "示例公司",
    status: @moonextract.MatchStatus::Unique,
    evidence: [
      @moonextract.Evidence::{
        document_id: "contract",
        span: @moonextract.Span::{ start: 0, end: 5, },
        text: "示例公司",
      },
    ],
  }
  match @moonextract.validate_extraction(document, overlong) {
    Err(@moonextract.ValidationError::InvalidEvidenceSpan(0, 0, 5)) => ()
    _ => fail("overlong evidence span must be rejected")
  }
}

///|
test "validation rejects status count and duplicate span mismatches" {
  let document = @moonextract.Document::{ id: "doc", text: "aaaa", }
  let empty_unique = @moonextract.Extraction::{
    field: "value",
    value: "aa",
    normalized_value: "aa",
    status: @moonextract.MatchStatus::Unique,
    evidence: [],
  }
  match @moonextract.validate_extraction(document, empty_unique) {
    Err(@moonextract.ValidationError::StatusEvidenceCountMismatch(1, 0)) => ()
    _ => fail("unique status requires one evidence span")
  }
  let duplicate = @moonextract.Extraction::{
    field: "value",
    value: "aa",
    normalized_value: "aa",
    status: @moonextract.MatchStatus::Ambiguous,
    evidence: [
      @moonextract.Evidence::{
        document_id: "doc",
        span: @moonextract.Span::{ start: 0, end: 2, },
        text: "aa",
      },
      @moonextract.Evidence::{
        document_id: "doc",
        span: @moonextract.Span::{ start: 0, end: 2, },
        text: "aa",
      },
    ],
  }
  match @moonextract.validate_extraction(document, duplicate) {
    Err(@moonextract.ValidationError::DuplicateEvidenceSpan(0, 2)) => ()
    _ => fail("duplicate evidence spans must be rejected")
  }
}

///|
test "validation rejects a value that differs from its evidence" {
  let document = @moonextract.Document::{ id: "doc", text: "hello", }
  let extraction = @moonextract.Extraction::{
    field: "word",
    value: "world",
    normalized_value: "world",
    status: @moonextract.MatchStatus::Unique,
    evidence: [
      @moonextract.Evidence::{
        document_id: "doc",
        span: @moonextract.Span::{ start: 0, end: 5, },
        text: "hello",
      },
    ],
  }
  match @moonextract.validate_extraction(document, extraction) {
    Err(@moonextract.ValidationError::ValueEvidenceMismatch("world", "hello")) =>
      ()
    _ => fail("value and evidence must agree")
  }
}
