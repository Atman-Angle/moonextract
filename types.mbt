///|
/// A source document identified by a stable caller-provided id.
///
/// Span offsets in MoonExtract are Unicode code-point indices into `text`.
/// Fields are private so every document passes `Document::new` validation.
pub struct Document {
  priv id : String
  priv text : String
  priv chars : Array[Char]
}

///|
pub fn Document::id(self : Document) -> String {
  self.id
}

///|
pub fn Document::text(self : Document) -> String {
  self.text
}

///|
/// A half-open code-point range `[start, end)`.
///
/// Fields are private so callers must use `Span::new`.
pub struct Span {
  priv start : Int32
  priv end : Int32
}

///|
pub fn Span::start(self : Span) -> Int32 {
  self.start
}

///|
pub fn Span::end(self : Span) -> Int32 {
  self.end
}

///|
/// A verbatim slice of a document that supports one extraction candidate.
///
/// Evidence is created by matching functions after the source text and span
/// have already been checked.
pub struct Evidence {
  priv document_id : String
  priv span : Span
  priv text : String
}

///|
pub fn Evidence::document_id(self : Evidence) -> String {
  self.document_id
}

///|
pub fn Evidence::span(self : Evidence) -> Span {
  self.span
}

///|
pub fn Evidence::text(self : Evidence) -> String {
  self.text
}

///|
/// The outcome of locating a candidate in a document.
pub(all) enum MatchStatus {
  Unique
  Ambiguous
  Missing
}

///|
pub impl Eq for MatchStatus with fn equal(self, other) {
  match (self, other) {
    (Unique, Unique) => true
    (Ambiguous, Ambiguous) => true
    (Missing, Missing) => true
    _ => false
  }
}

///|
pub impl Eq for MatchStatus with fn not_equal(self, other) {
  !self.equal(other)
}

///|
pub extend MatchStatus with Eq::{equal, not_equal}

///|
/// All evidence found for one candidate search.
pub struct MatchResult {
  priv status : MatchStatus
  priv matches : Array[Evidence]
}

///|
pub fn MatchResult::status(self : MatchResult) -> MatchStatus {
  self.status
}

///|
/// Read-only view of every matching evidence record, in source order.
pub fn MatchResult::matches(self : MatchResult) -> ArrayView[Evidence] {
  self.matches
}

///|
/// A candidate extracted by an upstream producer and its supporting evidence.
///
/// Extraction values are created by `Document::extract` or
/// `Document::extract_normalized`, which derive status and evidence together.
pub struct Extraction {
  priv field : String
  priv value : String
  priv normalized_value : String
  priv status : MatchStatus
  priv evidence : Array[Evidence]
}

///|
pub fn Extraction::field(self : Extraction) -> String {
  self.field
}

///|
pub fn Extraction::value(self : Extraction) -> String {
  self.value
}

///|
pub fn Extraction::normalized_value(self : Extraction) -> String {
  self.normalized_value
}

///|
pub fn Extraction::status(self : Extraction) -> MatchStatus {
  self.status
}

///|
/// Read-only view of every evidence record, in source order.
pub fn Extraction::evidence(self : Extraction) -> ArrayView[Evidence] {
  self.evidence
}
