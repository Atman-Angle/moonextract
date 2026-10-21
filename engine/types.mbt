///|
/// A field requested from the model.
pub struct FieldDefinition {
  priv name : String
  priv description : String
  priv required : Bool
  priv repeatable : Bool
}

///|
pub fn FieldDefinition::new(
  name~ : String,
  description~ : String,
  required~ : Bool = true,
  repeatable~ : Bool = false,
) -> FieldDefinition {
  { name, description, required, repeatable, }
}

///|
pub fn FieldDefinition::name(self : FieldDefinition) -> String {
  self.name
}

///|
pub fn FieldDefinition::description(self : FieldDefinition) -> String {
  self.description
}

///|
pub fn FieldDefinition::required(self : FieldDefinition) -> Bool {
  self.required
}

///|
pub fn FieldDefinition::repeatable(self : FieldDefinition) -> Bool {
  self.repeatable
}

///|
pub fn FieldDefinition::to_json(self : FieldDefinition) -> Json {
  Json::object({
    "name": Json::string(self.name),
    "description": Json::string(self.description),
    "required": Json::boolean(self.required),
    "repeatable": Json::boolean(self.repeatable),
  })
}

///|
/// One field value proposed by a model.
///
/// `quote` is expected to be verbatim source text. `value` is the value the
/// caller wants to keep and may differ by whitespace or formatting. `context`
/// is an optional nearby phrase used to disambiguate repeated quotes.
pub struct LlmClaim {
  priv field : String
  priv value : String
  priv quote : String
  priv context : String?
}

///|
pub fn LlmClaim::new(
  field~ : String,
  value~ : String,
  quote~ : String,
  context? : String,
) -> LlmClaim {
  { field, value, quote, context, }
}

///|
pub fn LlmClaim::field(self : LlmClaim) -> String {
  self.field
}

///|
pub fn LlmClaim::value(self : LlmClaim) -> String {
  self.value
}

///|
pub fn LlmClaim::quote(self : LlmClaim) -> String {
  self.quote
}

///|
pub fn LlmClaim::context(self : LlmClaim) -> String? {
  self.context
}

///|
/// The prompt handed to a model provider.
pub struct Prompt {
  priv system : String
  priv user : String
}

///|
pub fn Prompt::new(system~ : String, user~ : String) -> Prompt {
  { system, user, }
}

///|
pub fn Prompt::system(self : Prompt) -> String {
  self.system
}

///|
pub fn Prompt::user(self : Prompt) -> String {
  self.user
}

///|
/// The evidence state of one field result.
pub(all) enum FieldStatus {
  Resolved
  MissingSource
  AmbiguousSource
  Conflict
}

///|
pub fn FieldStatus::name(status : FieldStatus) -> String {
  match status {
    Resolved => "resolved"
    MissingSource => "missing_source"
    AmbiguousSource => "ambiguous_source"
    Conflict => "conflict"
  }
}

///|
/// Structured diagnostics returned with an extraction.
pub(all) enum Diagnostic {
  UnknownField(String)
  MissingSource(String, String)
  AmbiguousSource(String, String, Int32)
  ContextMismatch(String, String, String)
  MissingRequiredField(String)
  FieldConflict(String, Array[String])
  DuplicateClaim(String, String)
}

///|
fn diagnostic_to_json(diagnostic : Diagnostic) -> Json {
  match diagnostic {
    UnknownField(field) =>
      Json::object({
        "code": Json::string("unknown_field"),
        "field": Json::string(field),
        "message": Json::string(
          "model returned a field that is not in the plan",
        ),
      })
    MissingSource(field, quote) =>
      Json::object({
        "code": Json::string("missing_source"),
        "field": Json::string(field),
        "quote": Json::string(quote),
        "message": Json::string(
          "the proposed quote was not found in the document",
        ),
      })
    AmbiguousSource(field, quote, count) =>
      Json::object({
        "code": Json::string("ambiguous_source"),
        "field": Json::string(field),
        "quote": Json::string(quote),
        "count": Json::number(count.to_double()),
        "message": Json::string("the proposed quote occurs more than once"),
      })
    ContextMismatch(field, quote, context) =>
      Json::object({
        "code": Json::string("context_mismatch"),
        "field": Json::string(field),
        "quote": Json::string(quote),
        "context": Json::string(context),
        "message": Json::string(
          "no quoted occurrence matched the supplied context",
        ),
      })
    MissingRequiredField(field) =>
      Json::object({
        "code": Json::string("missing_required_field"),
        "field": Json::string(field),
        "message": Json::string(
          "the model returned no claim for a required field",
        ),
      })
    FieldConflict(field, values) => {
      let json_values : Array[Json] = []
      for value in values {
        json_values.push(Json::string(value))
      }
      Json::object({
        "code": Json::string("field_conflict"),
        "field": Json::string(field),
        "values": Json::array(json_values),
        "message": Json::string(
          "non-repeatable field received different values",
        ),
      })
    }
    DuplicateClaim(field, value) =>
      Json::object({
        "code": Json::string("duplicate_claim"),
        "field": Json::string(field),
        "value": Json::string(value),
        "message": Json::string("duplicate claim was ignored"),
      })
  }
}

///|
/// One extracted field and the source evidence attached to it.
pub struct FieldResult {
  priv field : String
  priv value : String
  priv normalized_value : String
  priv quote : String
  priv context : String?
  priv status : FieldStatus
  priv evidence : Array[@moonextract.Evidence]
}

///|
pub fn FieldResult::field(self : FieldResult) -> String {
  self.field
}

///|
pub fn FieldResult::value(self : FieldResult) -> String {
  self.value
}

///|
pub fn FieldResult::normalized_value(self : FieldResult) -> String {
  self.normalized_value
}

///|
pub fn FieldResult::quote(self : FieldResult) -> String {
  self.quote
}

///|
pub fn FieldResult::context(self : FieldResult) -> String? {
  self.context
}

///|
pub fn FieldResult::status(self : FieldResult) -> FieldStatus {
  self.status
}

///|
pub fn FieldResult::status_name(self : FieldResult) -> String {
  self.status.name()
}

///|
pub fn FieldResult::evidence(
  self : FieldResult,
) -> ArrayView[@moonextract.Evidence] {
  self.evidence
}

///|
pub fn FieldResult::to_json(self : FieldResult) -> Json {
  let evidence_json : Array[Json] = []
  for evidence in self.evidence {
    evidence_json.push(evidence.to_json())
  }
  Json::object({
    "field": Json::string(self.field),
    "value": Json::string(self.value),
    "normalized_value": Json::string(self.normalized_value),
    "quote": Json::string(self.quote),
    "context": match self.context {
      Some(context) => Json::string(context)
      None => Json::null()
    },
    "status": Json::string(self.status.name()),
    "evidence": Json::array(evidence_json),
  })
}

///|
/// The complete result of one document extraction.
pub struct ExtractionReport {
  priv document_id : String
  priv fields : Array[FieldResult]
  priv diagnostics : Array[Diagnostic]
  priv chunk_count : Int32
}

///|
pub fn ExtractionReport::document_id(self : ExtractionReport) -> String {
  self.document_id
}

///|
pub fn ExtractionReport::fields(
  self : ExtractionReport,
) -> ArrayView[FieldResult] {
  self.fields
}

///|
pub fn ExtractionReport::diagnostics(
  self : ExtractionReport,
) -> ArrayView[Diagnostic] {
  self.diagnostics
}

///|
pub fn ExtractionReport::chunk_count(self : ExtractionReport) -> Int32 {
  self.chunk_count
}

///|
pub fn ExtractionReport::to_json(self : ExtractionReport) -> Json {
  let field_json : Array[Json] = []
  for field in self.fields {
    field_json.push(field.to_json())
  }
  let diagnostic_json : Array[Json] = []
  for diagnostic in self.diagnostics {
    diagnostic_json.push(diagnostic_to_json(diagnostic))
  }
  Json::object({
    "document_id": Json::string(self.document_id),
    "chunk_count": Json::number(self.chunk_count.to_double()),
    "fields": Json::array(field_json),
    "diagnostics": Json::array(diagnostic_json),
  })
}

///|
pub fn ExtractionReport::to_json_string(
  self : ExtractionReport,
  indent? : Int32,
) -> String {
  self.to_json().stringify(indent?)
}

///|
/// Recoverable engine errors.
pub(all) suberror EngineError {
  NoFields
  DuplicateField(String)
  InvalidFieldDefinition(String)
  ModelFailed(String)
  InvalidModelOutput(String)
  InvalidChunk(String)
}
