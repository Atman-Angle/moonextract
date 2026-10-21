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
/// Return the distance to the nearest occurrence of `context`, if any.
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
fn make_field_result(
  claim : LlmClaim,
  status : FieldStatus,
  evidence : Array[@moonextract.Evidence],
) -> FieldResult {
  FieldResult::{
    field: claim.field(),
    value: claim.value(),
    normalized_value: @moonextract.normalize_whitespace(claim.value()),
    quote: claim.quote(),
    context: claim.context(),
    status,
    evidence,
  }
}

///|
fn resolve_one_claim(
  document : @moonextract.Document,
  claim : LlmClaim,
  diagnostics : Array[Diagnostic],
) -> FieldResult {
  if claim.quote().is_empty() {
    diagnostics.push(MissingSource(claim.field(), claim.quote()))
    return make_field_result(claim, MissingSource, [])
  }
  let matches = match document.find_all(claim.quote()) {
    Ok(matches) => matches
    Err(_) => {
      diagnostics.push(MissingSource(claim.field(), claim.quote()))
      return make_field_result(claim, MissingSource, [])
    }
  }
  if matches.length() == 0 {
    diagnostics.push(MissingSource(claim.field(), claim.quote()))
    return make_field_result(claim, MissingSource, [])
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
        return make_field_result(claim, MissingSource, [])
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
        return make_field_result(claim, AmbiguousSource, selected)
      }
      make_field_result(claim, Resolved, selected)
    }
    _ => {
      if matches.length() > 1 {
        diagnostics.push(
          AmbiguousSource(claim.field(), claim.quote(), matches.length()),
        )
        return make_field_result(claim, AmbiguousSource, matches)
      }
      make_field_result(claim, Resolved, matches)
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
/// Claims are first deduplicated because overlapping chunks can produce the same
/// claim more than once. Each remaining quote is resolved against the full
/// document, not the individual chunk, so a quote can be checked against every
/// source occurrence and the supplied context.
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
  let seen_claims : Map[String, Unit] = Map([])
  let results : Array[FieldResult] = []
  let diagnostics : Array[Diagnostic] = []
  for claim in claims {
    let known_field = match field_definition(fields, claim.field()) {
      Some(field) => field
      None => {
        diagnostics.push(UnknownField(claim.field()))
        continue
      }
    }
    let context_key = match claim.context() {
      Some(context) => context
      None => ""
    }
    let key = claim.field() +
      "\u{0}" +
      claim.value() +
      "\u{0}" +
      claim.quote() +
      "\u{0}" +
      context_key
    if seen_claims.contains(key) {
      continue
    }
    seen_claims.set(key, ())
    results.push(resolve_one_claim(document, claim, diagnostics))
    let _ = known_field
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
    diagnostics,
    chunk_count,
  })
}
