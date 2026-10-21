///|
/// The value comparison policy attached to a field definition.
pub(all) enum FieldValueKind {
  Text
  Number
}

///|
pub fn FieldValueKind::name(self : FieldValueKind) -> String {
  match self {
    Text => "text"
    Number => "number"
  }
}

///|
/// A field requested from the model.
pub struct FieldDefinition {
  priv name : String
  priv description : String
  priv required : Bool
  priv repeatable : Bool
  priv value_kind : FieldValueKind
}

///|
pub fn FieldDefinition::new(
  name~ : String,
  description~ : String,
  required~ : Bool = true,
  repeatable~ : Bool = false,
  value_kind~ : FieldValueKind = Text,
) -> FieldDefinition {
  { name, description, required, repeatable, value_kind, }
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
pub fn FieldDefinition::value_kind(self : FieldDefinition) -> FieldValueKind {
  self.value_kind
}

///|
pub fn FieldDefinition::to_json(self : FieldDefinition) -> Json {
  Json::object({
    "name": Json::string(self.name),
    "description": Json::string(self.description),
    "required": Json::boolean(self.required),
    "repeatable": Json::boolean(self.repeatable),
    "value_kind": Json::string(self.value_kind.name()),
  })
}

///|
/// The document chunk that produced a claim.
pub struct ClaimSource {
  priv index : Int32
  priv start : Int32
  priv end : Int32
}

///|
pub fn ClaimSource::new(
  index~ : Int32,
  start~ : Int32,
  end~ : Int32,
) -> ClaimSource {
  { index, start, end, }
}

///|
pub fn ClaimSource::index(self : ClaimSource) -> Int32 {
  self.index
}

///|
pub fn ClaimSource::start(self : ClaimSource) -> Int32 {
  self.start
}

///|
pub fn ClaimSource::end(self : ClaimSource) -> Int32 {
  self.end
}

///|
pub fn ClaimSource::to_json(self : ClaimSource) -> Json {
  Json::object({
    "index": Json::number(self.index.to_double()),
    "start": Json::number(self.start.to_double()),
    "end": Json::number(self.end.to_double()),
  })
}

///|
/// One field value proposed by a model.
///
/// `quote` is expected to be verbatim source text. `value` is the value the
/// caller wants to keep and may differ by whitespace or formatting. `context`
/// is an optional nearby phrase used to disambiguate repeated quotes. `source`
/// records the chunk that produced the claim when the engine supplied one.
pub struct LlmClaim {
  priv field : String
  priv value : String
  priv quote : String
  priv context : String?
  priv source : ClaimSource?
}

///|
pub fn LlmClaim::new(
  field~ : String,
  value~ : String,
  quote~ : String,
  context? : String,
  source? : ClaimSource,
) -> LlmClaim {
  { field, value, quote, context, source, }
}

///|
pub fn LlmClaim::with_source(self : LlmClaim, source : ClaimSource) -> LlmClaim {
  { ..self, source: Some(source), }
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
pub fn LlmClaim::source(self : LlmClaim) -> ClaimSource? {
  self.source
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
/// Whether a field value can be proven consistent with its source quote.
pub(all) enum ValueConsistency {
  Verified
  Unverified
  Mismatch
}

///|
pub fn ValueConsistency::name(self : ValueConsistency) -> String {
  match self {
    Verified => "verified"
    Unverified => "unverified"
    Mismatch => "mismatch"
  }
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
  ValueUnverified(String, String, String)
  ValueMismatch(String, String, String)
  SourceOutsideChunk(String, String, Int32)
  DuplicateClaim(String, String)
}

///|
pub fn Diagnostic::code(self : Diagnostic) -> String {
  match self {
    UnknownField(_) => "unknown_field"
    MissingSource(_, _) => "missing_source"
    AmbiguousSource(_, _, _) => "ambiguous_source"
    ContextMismatch(_, _, _) => "context_mismatch"
    MissingRequiredField(_) => "missing_required_field"
    FieldConflict(_, _) => "field_conflict"
    ValueUnverified(_, _, _) => "value_unverified"
    ValueMismatch(_, _, _) => "value_mismatch"
    SourceOutsideChunk(_, _, _) => "source_outside_chunk"
    DuplicateClaim(_, _) => "duplicate_claim"
  }
}

///|
pub fn Diagnostic::field(self : Diagnostic) -> String? {
  match self {
    UnknownField(field) => Some(field)
    MissingSource(field, _) => Some(field)
    AmbiguousSource(field, _, _) => Some(field)
    ContextMismatch(field, _, _) => Some(field)
    MissingRequiredField(field) => Some(field)
    FieldConflict(field, _) => Some(field)
    ValueUnverified(field, _, _) => Some(field)
    ValueMismatch(field, _, _) => Some(field)
    SourceOutsideChunk(field, _, _) => Some(field)
    DuplicateClaim(field, _) => Some(field)
  }
}

///|
fn diagnostic_to_json(diagnostic : Diagnostic) -> Json {
  match diagnostic {
    UnknownField(field) =>
      Json::object({
        "code": Json::string(diagnostic.code()),
        "field": Json::string(field),
        "message": Json::string(
          "model returned a field that is not in the plan",
        ),
      })
    MissingSource(field, quote) =>
      Json::object({
        "code": Json::string(diagnostic.code()),
        "field": Json::string(field),
        "quote": Json::string(quote),
        "message": Json::string(
          "the proposed quote was not found in the source chunk",
        ),
      })
    AmbiguousSource(field, quote, count) =>
      Json::object({
        "code": Json::string(diagnostic.code()),
        "field": Json::string(field),
        "quote": Json::string(quote),
        "count": Json::number(count.to_double()),
        "message": Json::string("the proposed quote occurs more than once"),
      })
    ContextMismatch(field, quote, context) =>
      Json::object({
        "code": Json::string(diagnostic.code()),
        "field": Json::string(field),
        "quote": Json::string(quote),
        "context": Json::string(context),
        "message": Json::string(
          "no quoted occurrence matched the supplied context",
        ),
      })
    MissingRequiredField(field) =>
      Json::object({
        "code": Json::string(diagnostic.code()),
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
        "code": Json::string(diagnostic.code()),
        "field": Json::string(field),
        "values": Json::array(json_values),
        "message": Json::string(
          "non-repeatable field received different values",
        ),
      })
    }
    ValueUnverified(field, value, quote) =>
      Json::object({
        "code": Json::string(diagnostic.code()),
        "field": Json::string(field),
        "value": Json::string(value),
        "quote": Json::string(quote),
        "message": Json::string(
          "the quote exists but the value relation cannot be proven",
        ),
      })
    ValueMismatch(field, value, quote) =>
      Json::object({
        "code": Json::string(diagnostic.code()),
        "field": Json::string(field),
        "value": Json::string(value),
        "quote": Json::string(quote),
        "message": Json::string(
          "the normalized value does not match the source quote",
        ),
      })
    SourceOutsideChunk(field, quote, chunk_index) =>
      Json::object({
        "code": Json::string(diagnostic.code()),
        "field": Json::string(field),
        "quote": Json::string(quote),
        "chunk_index": Json::number(chunk_index.to_double()),
        "message": Json::string(
          "the proposed quote does not occur in the claim's source chunk",
        ),
      })
    DuplicateClaim(field, value) =>
      Json::object({
        "code": Json::string(diagnostic.code()),
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
  priv value_consistency : ValueConsistency
  priv source_chunk : ClaimSource?
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
pub fn FieldResult::value_consistency(self : FieldResult) -> ValueConsistency {
  self.value_consistency
}

///|
pub fn FieldResult::value_consistency_name(self : FieldResult) -> String {
  self.value_consistency.name()
}

///|
pub fn FieldResult::source_chunk(self : FieldResult) -> ClaimSource? {
  self.source_chunk
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
    "value_consistency": Json::string(self.value_consistency.name()),
    "source_chunk": match self.source_chunk {
      Some(source) => source.to_json()
      None => Json::null()
    },
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
