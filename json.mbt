///|
fn status_name(status : MatchStatus) -> String {
  match status {
    Unique => "unique"
    Ambiguous => "ambiguous"
    Missing => "missing"
  }
}

///|
/// Convert a span to a JSON object with code-point boundaries.
pub fn Span::to_json(self : Span) -> Json {
  Json::object({
    "start": Json::number(self.start.to_double()),
    "end": Json::number(self.end.to_double()),
  })
}

///|
/// Convert evidence to deterministic JSON.
pub fn Evidence::to_json(self : Evidence) -> Json {
  Json::object({
    "document_id": Json::string(self.document_id),
    "span": self.span.to_json(),
    "text": Json::string(self.text),
  })
}

///|
/// Convert an extraction and all of its evidence to deterministic JSON.
pub fn Extraction::to_json(self : Extraction) -> Json {
  let evidence : Array[Json] = []
  for index = 0; index < self.evidence.length(); index = index + 1 {
    evidence.push(self.evidence[index].to_json())
  }
  Json::object({
    "field": Json::string(self.field),
    "value": Json::string(self.value),
    "normalized_value": Json::string(self.normalized_value),
    "status": Json::string(status_name(self.status)),
    "evidence": Json::array(evidence),
  })
}

///|
/// Serialize an extraction as JSON text.
pub fn Extraction::to_json_string(self : Extraction, indent? : Int32) -> String {
  self.to_json().stringify(indent?)
}
