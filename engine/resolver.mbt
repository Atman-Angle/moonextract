///|
const CONTEXT_WINDOW : Int32 = 96

///|
fn field_definition(
  fields : Array[FieldDefinition],
  name : String,
) -> FieldDefinition? {
  for field in fields {
    if field.name() == name {
      return Some(field)
    }
  }
  None
}

///|
fn span_distance(left : @moonextract.Span, right : @moonextract.Span) -> Int32 {
  if left.end() <= right.start() {
    right.start() - left.end()
  } else if right.end() <= left.start() {
    left.start() - right.end()
  } else {
    0
  }
}

///|
fn context_distance(
  document : @moonextract.Document,
  evidence : @moonextract.Evidence,
  context : String,
) -> Int32? {
  let context_matches = match document.find_all(context) {
    Ok(matches) => matches
    Err(_) => return None
  }
  if context_matches.length() == 0 {
    return None
  }
  let mut best = 2147483647
  for context_evidence in context_matches {
    let distance = span_distance(evidence.span(), context_evidence.span())
    let direction_penalty = if context_evidence.span().end() <=
      evidence.span().start() {
      0
    } else {
      1
    }
    let score = distance * 2 + direction_penalty
    if score < best {
      best = score
    }
  }
  Some(best)
}

///|
fn normalized_claim_value(claim : LlmClaim, field : FieldDefinition) -> String {
  match field.value_kind() {
    Number =>
      match normalize_number(claim.value()) {
        Some(value) => value
        None => @moonextract.normalize_whitespace(claim.value())
      }
    Text => @moonextract.normalize_whitespace(claim.value())
  }
}

///|
fn make_field_result(
  field : FieldDefinition,
  claim : LlmClaim,
  status : FieldStatus,
  evidence : Array[@moonextract.Evidence],
  diagnostics : Array[Diagnostic],
) -> FieldResult {
  let mut consistency = Unverified
  let resolved = match status {
    Resolved => true
    _ => false
  }
  if resolved && evidence.length() == 1 {
    consistency = verify_value(field, claim, evidence[0])
    match consistency {
      Verified => ()
      Unverified =>
        diagnostics.push(
          ValueUnverified(claim.field(), claim.value(), claim.quote()),
        )
      Mismatch =>
        diagnostics.push(
          ValueMismatch(claim.field(), claim.value(), claim.quote()),
        )
    }
  }
  FieldResult::{
    field: claim.field(),
    value: claim.value(),
    normalized_value: normalized_claim_value(claim, field),
    quote: claim.quote(),
    context: claim.context(),
    status,
    value_consistency: consistency,
    source_chunk: claim.source(),
    evidence,
  }
}

///|
fn resolve_one_claim(
  document : @moonextract.Document,
  field : FieldDefinition,
  claim : LlmClaim,
  diagnostics : Array[Diagnostic],
) -> FieldResult {
  if claim.quote().is_empty() {
    diagnostics.push(MissingSource(claim.field(), claim.quote()))
    return make_field_result(field, claim, MissingSource, [], diagnostics)
  }
  let all_matches = match document.find_all(claim.quote()) {
    Ok(matches) => matches
    Err(_) => {
      diagnostics.push(MissingSource(claim.field(), claim.quote()))
      return make_field_result(field, claim, MissingSource, [], diagnostics)
    }
  }
  if all_matches.length() == 0 {
    diagnostics.push(MissingSource(claim.field(), claim.quote()))
    return make_field_result(field, claim, MissingSource, [], diagnostics)
  }
  let matches : Array[@moonextract.Evidence] = []
  match claim.source() {
    Some(source) => {
      for evidence in all_matches {
        if evidence.span().start() >= source.start() &&
          evidence.span().end() <= source.end() {
          matches.push(evidence)
        }
      }
      if matches.length() == 0 {
        diagnostics.push(
          SourceOutsideChunk(claim.field(), claim.quote(), source.index()),
        )
        return make_field_result(field, claim, MissingSource, [], diagnostics)
      }
    }
    None =>
      for evidence in all_matches {
        matches.push(evidence)
      }
  }
  let selected : Array[@moonextract.Evidence] = []
  match claim.context() {
    Some(context) if !context.is_blank() => {
      let scored : Array[(@moonextract.Evidence, Int32)] = []
      let mut nearest = CONTEXT_WINDOW * 2 + 2
      for evidence in matches {
        match context_distance(document, evidence, context) {
          Some(distance) if distance <= CONTEXT_WINDOW * 2 + 1 => {
            if distance < nearest {
              nearest = distance
            }
            scored.push((evidence, distance))
          }
          _ => ()
        }
      }
      if scored.length() == 0 {
        diagnostics.push(ContextMismatch(claim.field(), claim.quote(), context))
        return make_field_result(field, claim, MissingSource, [], diagnostics)
      }
      for item in scored {
        if item.1 == nearest {
          selected.push(item.0)
        }
      }
      if selected.length() > 1 {
        diagnostics.push(
          AmbiguousSource(claim.field(), claim.quote(), selected.length()),
        )
        return make_field_result(
          field,
          claim,
          AmbiguousSource,
          selected,
          diagnostics,
        )
      }
      make_field_result(field, claim, Resolved, selected, diagnostics)
    }
    _ => {
      if matches.length() > 1 {
        diagnostics.push(
          AmbiguousSource(claim.field(), claim.quote(), matches.length()),
        )
        return make_field_result(
          field,
          claim,
          AmbiguousSource,
          matches,
          diagnostics,
        )
      }
      make_field_result(field, claim, Resolved, matches, diagnostics)
    }
  }
}

///|
fn normalized_values_for(
  results : Array[FieldResult],
  field_name : String,
) -> Array[String] {
  let values : Array[String] = []
  for result in results {
    if result.field() == field_name && result.evidence().length() > 0 {
      let value = result.normalized_value()
      let mut found = false
      for existing in values {
        if existing == value {
          found = true
        }
      }
      if !found {
        values.push(value)
      }
    }
  }
  values
}

///|
fn result_key(result : FieldResult) -> String {
  let mut key = result.field() +
    "\u{0}" +
    result.value() +
    "\u{0}" +
    result.quote() +
    "\u{0}" +
    result.status_name()
  for evidence in result.evidence() {
    key = key +
      "\u{0}" +
      evidence.span().start().to_string() +
      ":" +
      evidence.span().end().to_string()
  }
  key
}

///|
fn append_unique_result(
  results : Array[FieldResult],
  seen : Map[String, Unit],
  result : FieldResult,
) -> Unit {
  let key = result_key(result)
  if !seen.contains(key) {
    seen.set(key, ())
    results.push(result)
  }
}

///|
fn diagnostic_key(diagnostic : Diagnostic) -> String {
  match diagnostic {
    UnknownField(value) => diagnostic.code() + "\u{0}" + value
    MissingSource(field, quote) =>
      diagnostic.code() + "\u{0}" + field + "\u{0}" + quote
    AmbiguousSource(field, quote, count) =>
      diagnostic.code() +
      "\u{0}" +
      field +
      "\u{0}" +
      quote +
      "\u{0}" +
      count.to_string()
    ContextMismatch(field, quote, context) =>
      diagnostic.code() + "\u{0}" + field + "\u{0}" + quote + "\u{0}" + context
    MissingRequiredField(field) => diagnostic.code() + "\u{0}" + field
    FieldConflict(field, values) =>
      diagnostic.code() + "\u{0}" + field + "\u{0}" + values.join(",")
    ValueUnverified(field, value, quote) =>
      diagnostic.code() + "\u{0}" + field + "\u{0}" + value + "\u{0}" + quote
    ValueMismatch(field, value, quote) =>
      diagnostic.code() + "\u{0}" + field + "\u{0}" + value + "\u{0}" + quote
    SourceOutsideChunk(field, quote, chunk_index) =>
      diagnostic.code() +
      "\u{0}" +
      field +
      "\u{0}" +
      quote +
      "\u{0}" +
      chunk_index.to_string()
    DuplicateClaim(field, value) =>
      diagnostic.code() + "\u{0}" + field + "\u{0}" + value
  }
}

///|
fn unique_diagnostics(diagnostics : Array[Diagnostic]) -> Array[Diagnostic] {
  let unique : Array[Diagnostic] = []
  let seen : Map[String, Unit] = Map([])
  for diagnostic in diagnostics {
    let key = diagnostic_key(diagnostic)
    if !seen.contains(key) {
      seen.set(key, ())
      unique.push(diagnostic)
    }
  }
  unique
}

///|

///|
fn has_result_for(results : Array[FieldResult], field_name : String) -> Bool {
  for result in results {
    if result.field() == field_name {
      return true
    }
  }
  false
}

///|
/// Resolve model claims against the complete source document.
///
/// A claim produced by a chunk carries the chunk's global boundaries. The quote
/// must occur inside that chunk, which prevents an overlapping chunk or a
/// repeated source string from being rebound to a different location. Results
/// that resolve to the same field, value, quote, status, and evidence span are
/// deduplicated after resolution.
#warnings("-result_error_return")
pub fn resolve_claims(
  document : @moonextract.Document,
  fields : Array[FieldDefinition],
  claims : Array[LlmClaim],
  chunk_count : Int32,
) -> Result[ExtractionReport, EngineError] {
  if fields.length() == 0 {
    return Err(NoFields)
  }
  let field_names : Map[String, Unit] = Map([])
  for field in fields {
    if field_names.contains(field.name()) {
      return Err(DuplicateField(field.name()))
    }
    field_names.set(field.name(), ())
  }
  let results : Array[FieldResult] = []
  let diagnostics : Array[Diagnostic] = []
  let seen_results : Map[String, Unit] = Map([])
  for claim in claims {
    let field = match field_definition(fields, claim.field()) {
      Some(field) => field
      None => {
        diagnostics.push(UnknownField(claim.field()))
        continue
      }
    }
    let result = resolve_one_claim(document, field, claim, diagnostics)
    append_unique_result(results, seen_results, result)
  }
  for field in fields {
    let values = normalized_values_for(results, field.name())
    if !field.repeatable() && values.length() > 1 {
      diagnostics.push(FieldConflict(field.name(), values))
      for index = 0; index < results.length(); index = index + 1 {
        if results[index].field() == field.name() {
          results[index] = FieldResult::{ ..results[index], status: Conflict, }
        }
      }
    }
    if field.required() && !has_result_for(results, field.name()) {
      diagnostics.push(MissingRequiredField(field.name()))
    }
  }
  Ok(ExtractionReport::{
    document_id: document.id(),
    fields: results,
    diagnostics: unique_diagnostics(diagnostics),
    chunk_count,
  })
}
