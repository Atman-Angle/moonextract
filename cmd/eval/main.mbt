///|
fn json_get_string(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn json_get_array(object : Map[String, Json], key : String) -> Array[Json]? {
  match object.get(key) {
    Some(Array(items)) => Some(items)
    _ => None
  }
}

///|
fn fail(message : String) -> Unit {
  println("error: " + message)
  exit_process(1)
}

///|
fn evidence_spans(value : Json) -> Array[(Int32, Int32)] {
  let spans : Array[(Int32, Int32)] = []
  match value {
    Array(items) =>
      for item in items {
        match item {
          Object(object) => {
            let start = match object.get("start") {
              Some(Number(number, ..)) => number.to_int()
              _ => -1
            }
            let end = match object.get("end") {
              Some(Number(number, ..)) => number.to_int()
              _ => -1
            }
            if start >= 0 && end >= 0 {
              spans.push((start, end))
            }
          }
          _ => ()
        }
      }
    _ => ()
  }
  spans
}

///|
fn evidence_matches(
  evidence : ArrayView[@moonextract.Evidence],
  expected : Array[(Int32, Int32)],
) -> Bool {
  if evidence.length() != expected.length() {
    return false
  }
  for index = 0; index < evidence.length(); index = index + 1 {
    if evidence[index].span().start() != expected[index].0 ||
      evidence[index].span().end() != expected[index].1 {
      return false
    }
  }
  true
}

///|
fn expected_value(expected : Map[String, Json], key : String) -> String {
  match json_get_string(expected, key) {
    Some(value) => value
    None => ""
  }
}

///|
fn engine_matches(
  report : @engine.ExtractionReport,
  expected : Map[String, Json],
) -> Bool {
  let field = expected_value(expected, "field")
  let value = expected_value(expected, "value")
  let quote = expected_value(expected, "quote")
  let status = expected_value(expected, "status")
  let expected_evidence = match expected.get("evidence") {
    Some(value) => evidence_spans(value)
    None => []
  }
  for result in report.fields() {
    if result.field() == field &&
      result.value() == value &&
      result.quote() == quote &&
      result.status_name() == status &&
      evidence_matches(result.evidence(), expected_evidence) {
      return true
    }
  }
  false
}

///|
fn find_claim(claims : Array[Json], expected : Map[String, Json]) -> String? {
  let field = expected_value(expected, "field")
  let value = expected_value(expected, "value")
  let quote = expected_value(expected, "quote")
  for item in claims {
    match item {
      Object(claim) => {
        let claim_field = match json_get_string(claim, "field") {
          Some(value) => value
          None => ""
        }
        let claim_value = match json_get_string(claim, "value") {
          Some(value) => value
          None => ""
        }
        let claim_quote = match json_get_string(claim, "quote") {
          Some(value) => value
          None => ""
        }
        if claim_field == field && claim_value == value && claim_quote == quote {
          return Some(claim_value)
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn baseline_matches(
  document : @moonextract.Document,
  claims : Array[Json],
  expected : Map[String, Json],
) -> Bool {
  let field = expected_value(expected, "field")
  let status = expected_value(expected, "status")
  let expected_evidence = match expected.get("evidence") {
    Some(value) => evidence_spans(value)
    None => []
  }
  if status == "conflict" {
    return false
  }
  let claim_value = match find_claim(claims, expected) {
    Some(value) => value
    None => return false
  }
  let extraction = match document.extract_normalized(field, claim_value) {
    Ok(extraction) => extraction
    Err(_) => return false
  }
  if status == "missing_source" {
    return extraction.status() == @moonextract.MatchStatus::Missing
  }
  if status == "ambiguous_source" {
    return extraction.status() == @moonextract.MatchStatus::Ambiguous &&
      evidence_matches(extraction.evidence(), expected_evidence)
  }
  extraction.status() == @moonextract.MatchStatus::Unique &&
  evidence_matches(extraction.evidence(), expected_evidence)
}

///|
fn case_summary(
  id : String,
  engine_correct : Int32,
  baseline_correct : Int32,
  expected_total : Int32,
  diagnostics : Int32,
  chunks : Int32,
) -> Json {
  Json::object({
    "case": Json::string(id),
    "engine_correct": Json::number(engine_correct.to_double()),
    "baseline_correct": Json::number(baseline_correct.to_double()),
    "expected": Json::number(expected_total.to_double()),
    "diagnostics": Json::number(diagnostics.to_double()),
    "chunks": Json::number(chunks.to_double()),
  })
}

///|

///|
#warnings("-unused_async")
async fn recorded_complete(
  output : String,
  _prompt : @engine.Prompt,
) -> Result[String, String] {
  Ok(output)
}

///|
async fn evaluate_file(path : String) -> Result[Json, String] {
  let text = @fs.read_file(path).text() catch {
    _ => return Err("cannot read dataset: " + path)
  }
  let fields = match @engine.parse_field_definitions(text) {
    Ok(fields) => fields
    Err(_) => return Err("dataset field definitions are invalid: " + path)
  }
  let root = @json.parse(text) catch {
    _ => return Err("dataset is not valid JSON: " + path)
  }
  let root_object = match root {
    Object(object) => object
    _ => return Err("dataset root must be an object: " + path)
  }
  let scenario = match json_get_string(root_object, "scenario") {
    Some(value) => value
    None => "unknown"
  }
  let cases = match json_get_array(root_object, "cases") {
    Some(cases) => cases
    None => return Err("dataset must contain cases: " + path)
  }
  let case_summaries : Array[Json] = []
  let mut engine_total = 0
  let mut baseline_total = 0
  let mut expected_total = 0
  for case_json in cases {
    let case = match case_json {
      Object(case) => case
      _ => return Err("dataset case must be an object: " + path)
    }
    let id = match json_get_string(case, "id") {
      Some(value) => value
      None => return Err("dataset case needs an id: " + path)
    }
    let document_text = match json_get_string(case, "document") {
      Some(value) => value
      None => return Err("dataset case needs a document: " + path)
    }
    let document = match @moonextract.Document::new(id, document_text) {
      Ok(document) => document
      Err(_) => return Err("dataset document is invalid: " + id)
    }
    let claims_json = match json_get_array(case, "claims") {
      Some(claims) => claims
      None => return Err("dataset case needs claims: " + id)
    }
    let expected_json = match json_get_array(case, "expected") {
      Some(expected) => expected
      None => return Err("dataset case needs expected results: " + id)
    }
    let model_output = Json::object({ "claims": Json::array(claims_json) }).stringify()
    let report = match
      @engine.extract_with_model(
        document,
        fields,
        async fn(prompt) { recorded_complete(model_output, prompt) },
        chunk_size=40,
        overlap=10,
      ) {
      Ok(report) => report
      Err(_) => return Err("engine failed on case: " + id)
    }
    let mut engine_correct = 0
    let mut baseline_correct = 0
    for expected_value_json in expected_json {
      let expected = match expected_value_json {
        Object(expected) => expected
        _ => return Err("expected result must be an object: " + id)
      }
      if engine_matches(report, expected) {
        engine_correct = engine_correct + 1
      }
      if baseline_matches(document, claims_json, expected) {
        baseline_correct = baseline_correct + 1
      }
    }
    let expected_count = expected_json.length()
    engine_total = engine_total + engine_correct
    baseline_total = baseline_total + baseline_correct
    expected_total = expected_total + expected_count
    case_summaries.push(
      case_summary(
        id,
        engine_correct,
        baseline_correct,
        expected_count,
        report.diagnostics().length(),
        report.chunk_count(),
      ),
    )
  }
  Ok(
    Json::object({
      "scenario": Json::string(scenario),
      "cases": Json::array(case_summaries),
      "summary": Json::object({
        "engine_correct": Json::number(engine_total.to_double()),
        "baseline_correct": Json::number(baseline_total.to_double()),
        "expected": Json::number(expected_total.to_double()),
        "engine_accuracy": Json::number(
          if expected_total == 0 {
            0.0
          } else {
            engine_total.to_double() / expected_total.to_double()
          },
        ),
        "baseline_accuracy": Json::number(
          if expected_total == 0 {
            0.0
          } else {
            baseline_total.to_double() / expected_total.to_double()
          },
        ),
      }),
    }),
  )
}

///|
async fn main {
  let args = @env.args()
  if args.length() < 2 {
    println("Usage: moon run --target native cmd/eval -- <dataset.json> [...]")
    exit_process(1)
    return
  }
  let results : Array[Json] = []
  let mut index = 1
  while index < args.length() {
    let result = match evaluate_file(args[index]) {
      Ok(result) => result
      Err(message) => {
        fail(message)
        return
      }
    }
    results.push(result)
    index = index + 1
  }
  let output = Json::array(results)
  println(output.stringify(indent=2))
}
