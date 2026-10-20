///|
/// A source document identified by a stable caller-provided id.
///
/// Span offsets in MoonExtract are Unicode code-point indices into `text`.
pub(all) struct Document {
  id : String
  text : String
}

///|
/// A half-open code-point range `[start, end)`.
pub(all) struct Span {
  start : Int32
  end : Int32
}

///|
/// A verbatim slice of a document that supports one extraction candidate.
pub(all) struct Evidence {
  document_id : String
  span : Span
  text : String
}

///|
/// The outcome of locating a candidate in a document.
pub(all) enum MatchStatus {
  Unique
  Ambiguous
  Missing
}

///|
/// All evidence found for one candidate search.
pub(all) struct MatchResult {
  status : MatchStatus
  matches : Array[Evidence]
}

///|
/// A candidate extracted by an upstream producer and its supporting evidence.
pub(all) struct Extraction {
  field : String
  value : String
  normalized_value : String
  status : MatchStatus
  evidence : Array[Evidence]
}
