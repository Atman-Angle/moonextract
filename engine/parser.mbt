///|
fn strip_code_fence(output : String) -> String {
  let trimmed = output.trim()
  if !trimmed.has_prefix("```") {
    return trimmed.to_owned()
  }
  let lines = trimmed.split("\n").map(line => line.to_owned()).collect()
  if lines.length() < 3 {
    return trimmed.to_owned()
  }
  let mut body = ""
  let mut index = 1
  while index < lines.length() - 1 {
    if index > 1 {
      body = body + "\n"
    }
    body = body + lines[index].trim_end().to_owned()
    index = index + 1
  }
  body
}

///|
fn json_string_field(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn json_bool_field(object : Map[String, Json], key : String) -> Bool? {
  match object.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
/// Parse one field definition object.
#warnings("-result_error_return")
pub fn FieldDefinition::from_json(
  value : Json,
) -> Result[FieldDefinition, EngineError] {
  match value {
    Object(object) => {
      let name = match json_string_field(object, "name") {
        Some(name) if !name.is_blank() => name
        _ =>
          return Err(
            InvalidFieldDefinition("field name must be a non-empty string"),
          )
      }
      let description = match json_string_field(object, "description") {
        Some(description) => description
        None => ""
      }
      let required = json_bool_field(object, "required").unwrap_or(true)
      let repeatable = json_bool_field(object, "repeatable").unwrap_or(false)
      Ok(FieldDefinition::new(name~, description~, required~, repeatable~))
    }
    _ => Err(InvalidFieldDefinition("field definition must be an object"))
  }
}

///|
/// Parse an array of field definitions, or an object with a `fields` array.
#warnings("-result_error_return")
pub fn parse_field_definitions(
  text : String,
) -> Result[Array[FieldDefinition], EngineError] {
  let json = @json.parse(text) catch {
    _ =>
      return Err(InvalidFieldDefinition("field definitions are not valid JSON"))
  }
  let items = match json {
    Array(items) => items
    Object(object) =>
      match object.get("fields") {
        Some(Array(items)) => items
        _ =>
          return Err(
            InvalidFieldDefinition("field definitions must be an array"),
          )
      }
    _ =>
      return Err(InvalidFieldDefinition("field definitions must be an array"))
  }
  let fields : Array[FieldDefinition] = []
  for item in items {
    match FieldDefinition::from_json(item) {
      Ok(field) => fields.push(field)
      Err(error) => return Err(error)
    }
  }
  Ok(fields)
}

///|
/// Parse the model response into structured claims.
///
/// The parser accepts a bare JSON object with a `claims` array and tolerates a
/// single Markdown code fence around the JSON. It deliberately does not repair
/// malformed JSON; malformed model output is visible as a model-output error.
#warnings("-result_error_return")
pub fn parse_model_output(
  output : String,
) -> Result[Array[LlmClaim], EngineError] {
  let text = strip_code_fence(output)
  let json = @json.parse(text) catch {
    _ => return Err(InvalidModelOutput("model response is not valid JSON"))
  }
  let items = match json {
    Object(object) =>
      match object.get("claims") {
        Some(Array(items)) => items
        _ =>
          return Err(
            InvalidModelOutput("model response must contain a claims array"),
          )
      }
    _ => return Err(InvalidModelOutput("model response must be an object"))
  }
  let claims : Array[LlmClaim] = []
  for item in items {
    match item {
      Object(object) => {
        let field = match json_string_field(object, "field") {
          Some(field) if !field.is_blank() => field
          _ =>
            return Err(
              InvalidModelOutput("claim field must be a non-empty string"),
            )
        }
        let value = match json_string_field(object, "value") {
          Some(value) if !value.is_empty() => value
          _ =>
            return Err(
              InvalidModelOutput("claim value must be a non-empty string"),
            )
        }
        let quote = match json_string_field(object, "quote") {
          Some(quote) => quote
          None => ""
        }
        let context = match json_string_field(object, "context") {
          Some(context) if !context.is_blank() => Some(context)
          _ => None
        }
        claims.push(LlmClaim::new(field~, value~, quote~, context?))
      }
      _ => return Err(InvalidModelOutput("each claim must be an object"))
    }
  }
  Ok(claims)
}
