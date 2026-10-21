///|
fn env_or(name : String, fallback : String) -> String {
  match @env.get_env_var(name) {
    Some(value) if !value.is_blank() => value
    _ => fallback
  }
}

///|
fn fail(message : String) -> Unit {
  println("error: " + message)
  exit_process(1)
}

///|
fn usage() -> Unit {
  println("Usage: moon run cmd/extract -- <fields.json> <document.txt>")
  println("Environment: MOONEXTRACT_API_KEY or OPENAI_API_KEY")
  println("             MOONEXTRACT_MODEL (default: gpt-4.1-mini)")
  println(
    "             MOONEXTRACT_BASE_URL (default: https://api.openai.com/v1)",
  )
}

///|
async fn main {
  let args = @env.args()
  if args.length() != 3 {
    usage()
    exit_process(1)
    return
  }
  let fields_text = @fs.read_file(args[1]).text() catch {
    _ => {
      fail("cannot read field definitions: " + args[1])
      return
    }
  }
  let document_text = @fs.read_file(args[2]).text() catch {
    _ => {
      fail("cannot read document: " + args[2])
      return
    }
  }
  let fields = match @engine.parse_field_definitions(fields_text) {
    Ok(fields) => fields
    Err(@engine.EngineError::InvalidFieldDefinition(message)) => {
      fail(message)
      return
    }
    Err(@engine.EngineError::NoFields) => {
      fail("field definitions are empty")
      return
    }
    Err(_) => {
      fail("invalid field definitions")
      return
    }
  }
  let document = match @moonextract.Document::new("input", document_text) {
    Ok(document) => document
    Err(_) => {
      fail("document text must be valid UTF-16 and have a non-empty id")
      return
    }
  }
  let api_key = match @env.get_env_var("MOONEXTRACT_API_KEY") {
    Some(value) if !value.is_blank() => value
    _ =>
      match @env.get_env_var("OPENAI_API_KEY") {
        Some(value) if !value.is_blank() => value
        _ => {
          fail("set MOONEXTRACT_API_KEY or OPENAI_API_KEY")
          return
        }
      }
  }
  let config = @llm.OpenAIConfig::new(
    api_key~,
    model=env_or("MOONEXTRACT_MODEL", "gpt-4.1-mini"),
    base_url=env_or("MOONEXTRACT_BASE_URL", "https://api.openai.com/v1"),
  )
  let report = match
    @engine.extract_with_model(document, fields, async fn(prompt) {
      @llm.complete(config, prompt)
    }) {
    Ok(report) => report
    Err(@engine.EngineError::ModelFailed(message)) => {
      fail("model request failed: " + message)
      return
    }
    Err(@engine.EngineError::InvalidModelOutput(message)) => {
      fail("model output is invalid: " + message)
      return
    }
    Err(_) => {
      fail("extraction failed")
      return
    }
  }
  println(report.to_json_string(indent=2))
}
