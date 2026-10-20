///|
fn validation_wb_document(id : String, text : String) -> Document raise {
  match Document::new(id, text) {
    Ok(document) => document
    Err(_) => fail("test document should be valid")
  }
}

///|
fn validation_wb_evidence(
  document_id : String,
  start : Int32,
  end : Int32,
  text : String,
) -> Evidence {
  Evidence::{ document_id, span: Span::{ start, end, }, text, }
}

///|
test "validation rejects missing status when the value exists" {
  let document = validation_wb_document("doc", "aa")
  let extraction = Extraction::{
    field: "value",
    value: "aa",
    normalized_value: "aa",
    status: Missing,
    evidence: [],
  }
  match validate_extraction(document, extraction) {
    Err(StatusMismatch(Unique, Missing)) => ()
    _ => fail("missing status must be rejected when the value exists")
  }
}

///|
test "validation rejects unique status when overlapping matches exist" {
  let document = validation_wb_document("doc", "aaaa")
  let extraction = Extraction::{
    field: "value",
    value: "aa",
    normalized_value: "aa",
    status: Unique,
    evidence: [validation_wb_evidence("doc", 0, 2, "aa")],
  }
  match validate_extraction(document, extraction) {
    Err(StatusMismatch(Ambiguous, Unique)) => ()
    _ => fail("unique status must be rejected when three matches exist")
  }
}

///|
test "validation rejects non-canonical span order" {
  let document = validation_wb_document("doc", "ab ab")
  let extraction = Extraction::{
    field: "value",
    value: "ab",
    normalized_value: "ab",
    status: Ambiguous,
    evidence: [
      validation_wb_evidence("doc", 3, 5, "ab"),
      validation_wb_evidence("doc", 0, 2, "ab"),
    ],
  }
  match validate_extraction(document, extraction) {
    Err(EvidenceSpanMismatch(0, 0, 2, 3, 5)) => ()
    _ => fail("evidence must follow source match order")
  }
}

///|
test "validation rejects duplicate spans with the expected count" {
  let document = validation_wb_document("doc", "aaaa")
  let extraction = Extraction::{
    field: "value",
    value: "aa",
    normalized_value: "aa",
    status: Ambiguous,
    evidence: [
      validation_wb_evidence("doc", 0, 2, "aa"),
      validation_wb_evidence("doc", 0, 2, "aa"),
      validation_wb_evidence("doc", 2, 4, "aa"),
    ],
  }
  match validate_extraction(document, extraction) {
    Err(DuplicateEvidenceSpan(0, 2)) => ()
    _ => fail("duplicate evidence spans must be rejected")
  }
}

///|
test "validation rejects empty fields and values" {
  let document = validation_wb_document("doc", "hello")
  let empty_field = Extraction::{
    field: " ",
    value: "hello",
    normalized_value: "hello",
    status: Unique,
    evidence: [validation_wb_evidence("doc", 0, 5, "hello")],
  }
  match validate_extraction(document, empty_field) {
    Err(EmptyField) => ()
    _ => fail("blank field must be rejected")
  }
  let empty_value = Extraction::{
    field: "word",
    value: "",
    normalized_value: "",
    status: Missing,
    evidence: [],
  }
  match validate_extraction(document, empty_value) {
    Err(EmptyValue) => ()
    _ => fail("empty value must be rejected")
  }
}

///|
test "validation rejects stale text and foreign document ids" {
  let document = validation_wb_document("doc", "hello")
  let stale = Extraction::{
    field: "word",
    value: "hello",
    normalized_value: "hello",
    status: Unique,
    evidence: [validation_wb_evidence("doc", 0, 5, "world")],
  }
  match validate_extraction(document, stale) {
    Err(EvidenceTextMismatch(0, "hello", "world")) => ()
    _ => fail("stale evidence text must be rejected")
  }
  let foreign = Extraction::{
    field: "word",
    value: "hello",
    normalized_value: "hello",
    status: Unique,
    evidence: [validation_wb_evidence("other", 0, 5, "hello")],
  }
  match validate_extraction(document, foreign) {
    Err(WrongDocumentId(0, "doc", "other")) => ()
    _ => fail("foreign evidence must be rejected")
  }
}
