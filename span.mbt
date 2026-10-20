///|
/// Recoverable errors raised while validating or slicing code-point spans.
pub(all) suberror SpanError {
  InvalidSpan(Int32, Int32)
  SpanOutOfBounds(Int32, Int32, Int32)
}

///|
/// Construct a non-negative, ordered span.
#warnings("-result_error_return")
pub fn Span::new(start : Int32, end : Int32) -> Result[Span, SpanError] {
  if start < 0 || end < start {
    return Err(InvalidSpan(start, end))
  }
  Ok(Span::{ start, end, })
}

///|
/// Number of Unicode code points in the document text.
pub fn Document::char_length(self : Document) -> Int32 {
  self.chars.length()
}

///|
/// Return the verbatim text covered by `span`.
///
/// Offsets are code-point indices, not UTF-16 code units or UTF-8 bytes.
/// The document's code points are cached at construction, so slicing does not
/// copy the entire source text.
#warnings("-result_error_return")
pub fn Document::slice(
  self : Document,
  span : Span,
) -> Result[String, SpanError] {
  if span.start < 0 || span.end < span.start {
    return Err(InvalidSpan(span.start, span.end))
  }
  let length = self.char_length()
  if span.end > length {
    return Err(SpanOutOfBounds(span.start, span.end, length))
  }
  Ok(String::from_array(self.chars[span.start:span.end]))
}
