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
fn json_get_bool(object : Map[String, Json], key : String) -> Bool? {
  match object.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
fn fail(message : String) -> Unit {
  println("error: " + message)
  exit_process(1)
}

///|
fn expected_value(expected : Map[String, Json], key : String) -> String {
  match json_get_string(expected, key) {
    Some(value) => value
    None => ""
  }
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
fn result_matches_core(
  result : @engine.FieldResult,
  expected : Map[String, Json],
) -> Bool {
  result.field() == expected_value(expected, "field") &&
  result.value() == expected_value(expected, "value") &&
  result.normalized_value() == expected_value(expected, "normalized_value") &&
  result.quote() == expected_value(expected, "quote") &&
  result.status_name() == expected_value(expected, "status") &&
  result.value_consistency_name() ==
  expected_value(expected, "value_consistency")
}

///|
fn result_matches_full(
  result : @engine.FieldResult,
  expected : Map[String, Json],
) -> Bool {
  let expected_evidence = match expected.get("evidence") {
    Some(value) => evidence_spans(value)
    None => []
  }
  result_matches_core(result, expected) &&
  evidence_matches(result.evidence(), expected_evidence)
}

///|
fn report_has_core_match(
  report : @engine.ExtractionReport,
  expected : Map[String, Json],
) -> Bool {
  for result in report.fields() {
    if result_matches_core(result, expected) {
      return true
    }
  }
  false
}

///|
fn report_has_full_match(
  report : @engine.ExtractionReport,
  expected : Map[String, Json],
) -> Bool {
  for result in report.fields() {
    if result_matches_full(result, expected) {
      return true
    }
  }
  false
}

///|
fn count_false_positives(
  report : @engine.ExtractionReport,
  expected_json : Array[Json],
) -> Int32 {
  let mut count = 0
  for result in report.fields() {
    let mut matched = false
    for expected_json_value in expected_json {
      match expected_json_value {
        Object(expected) =>
          if result_matches_core(result, expected) {
            matched = true
          }
        _ => ()
      }
    }
    if !matched {
      count = count + 1
    }
  }
  count
}

///|
fn status_matches(actual : String, expected : String) -> Bool {
  if expected == "conflict" {
    false
  } else if expected == "resolved" {
    actual == "unique"
  } else if expected == "ambiguous_source" {
    actual == "ambiguous"
  } else if expected == "missing_source" {
    actual == "missing"
  } else {
    false
  }
}

///|
fn find_claim_value(
  claims : Array[Json],
  expected : Map[String, Json],
) -> String? {
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
fn baseline_value_correct(
  document : @moonextract.Document,
  claims : Array[Json],
  expected : Map[String, Json],
) -> Bool {
  let field = expected_value(expected, "field")
  let expected_status = expected_value(expected, "status")
  if expected_status == "conflict" {
    return false
  }
  let claim_value = match find_claim_value(claims, expected) {
    Some(value) => value
    None => return false
  }
  let extraction = match document.extract_normalized(field, claim_value) {
    Ok(extraction) => extraction
    Err(_) => return false
  }
  let actual_status = match extraction.status() {
    @moonextract.MatchStatus::Unique => "unique"
    @moonextract.MatchStatus::Ambiguous => "ambiguous"
    @moonextract.MatchStatus::Missing => "missing"
  }
  status_matches(actual_status, expected_status) &&
  extraction.normalized_value() == expected_value(expected, "normalized_value")
}

///|
fn baseline_full_correct(
  document : @moonextract.Document,
  claims : Array[Json],
  expected : Map[String, Json],
) -> Bool {
  if !baseline_value_correct(document, claims, expected) {
    return false
  }
  let field = expected_value(expected, "field")
  let claim_value = match find_claim_value(claims, expected) {
    Some(value) => value
    None => return false
  }
  let extraction = match document.extract_normalized(field, claim_value) {
    Ok(extraction) => extraction
    Err(_) => return false
  }
  let expected_evidence = match expected.get("evidence") {
    Some(value) => evidence_spans(value)
    None => []
  }
  evidence_matches(extraction.evidence(), expected_evidence)
}

///|
fn result_status_count(
  report : @engine.ExtractionReport,
  status_name : String,
) -> Int32 {
  let mut count = 0
  for result in report.fields() {
    if result.status_name() == status_name {
      count = count + 1
    }
  }
  count
}

///|
fn consistency_count(
  report : @engine.ExtractionReport,
  consistency_name : String,
) -> Int32 {
  let mut count = 0
  for result in report.fields() {
    if result.value_consistency_name() == consistency_name {
      count = count + 1
    }
  }
  count
}

///|
fn has_diagnostic(
  report : @engine.ExtractionReport,
  code : String,
  field : String,
) -> Bool {
  for diagnostic in report.diagnostics() {
    if diagnostic.code() == code {
      match diagnostic.field() {
        Some(actual_field) if actual_field == field => return true
        _ => ()
      }
    }
  }
  false
}

///|
fn prompt_document_text(user : String) -> String {
  match user.split_once("DOCUMENT:\n<<<\n") {
    Some((_, suffix)) =>
      match suffix.split_once("\n>>>") {
        Some((document, _)) => document.to_owned()
        None => user
      }
    None => user
  }
}

///|

///|
async fn recorded_complete(
  claims : Array[Json],
  prompt : @engine.Prompt,
  emitted : @ref.Ref[Int32],
) -> Result[String, String] {
  @async.pause()
  let document_text = prompt_document_text(prompt.user())
  let filtered : Array[Json] = []
  for item in claims {
    match item {
      Object(claim) => {
        let emit_regardless = json_get_bool(claim, "emit_regardless").unwrap_or(
          false,
        )
        let quote = match json_get_string(claim, "quote") {
          Some(value) => value
          None => ""
        }
        let context = match json_get_string(claim, "context") {
          Some(value) => value
          None => ""
        }
        let visible = emit_regardless ||
          (
            (quote != "" && document_text.contains(quote)) &&
            (context == "" || document_text.contains(context))
          )
        if visible {
          filtered.push(item)
        }
      }
      _ => ()
    }
  }
  emitted.val = emitted.val + filtered.length()
  Ok(Json::object({ "claims": Json::array(filtered) }).stringify())
}

///|
fn ratio(value : Int32, total : Int32) -> Double {
  if total == 0 {
    0.0
  } else {
    value.to_double() / total.to_double()
  }
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
  let mut engine_value_total = 0
  let mut engine_evidence_total = 0
  let mut engine_full_total = 0
  let mut baseline_value_total = 0
  let mut baseline_evidence_total = 0
  let mut baseline_full_total = 0
  let mut expected_total = 0
  let mut evidence_expected_total = 0
  let mut false_positive_total = 0
  let mut false_negative_total = 0
  let mut ambiguity_expected_total = 0
  let mut ambiguity_detected_total = 0
  let mut conflict_expected_total = 0
  let mut conflict_detected_total = 0
  let mut missing_expected_total = 0
  let mut missing_detected_total = 0
  let mut diagnostics_expected_total = 0
  let mut diagnostics_detected_total = 0
  let mut diagnostics_unexpected_total = 0
  let mut emitted_claims_total = 0
  let mut chunk_total = 0
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
    let expected_diagnostics_json = match case.get("expected_diagnostics") {
      Some(Array(items)) => items
      None => []
      _ => return Err("expected_diagnostics must be an array: " + id)
    }
    let emitted = @ref.Ref(0)
    let report = match
      @engine.extract_with_model(
        document,
        fields,
        async fn(prompt) { recorded_complete(claims_json, prompt, emitted) },
        chunk_size=50,
        overlap=20,
      ) {
      Ok(report) => report
      Err(_) => return Err("engine failed on case: " + id)
    }
    let mut engine_value_correct = 0
    let mut engine_evidence_correct = 0
    let mut engine_full_correct = 0
    let mut baseline_value_correct_count = 0
    let mut baseline_evidence_correct = 0
    let mut baseline_full_correct_count = 0
    let mut expected_count = 0
    let mut evidence_expected = 0
    let mut ambiguity_expected = 0
    let mut conflict_expected = 0
    let mut missing_expected = 0
    for expected_json_value in expected_json {
      let expected = match expected_json_value {
        Object(expected) => expected
        _ => return Err("expected result must be an object: " + id)
      }
      let expected_status = expected_value(expected, "status")
      let expected_evidence = match expected.get("evidence") {
        Some(value) => evidence_spans(value)
        None => []
      }
      expected_count = expected_count + 1
      if expected_evidence.length() > 0 {
        evidence_expected = evidence_expected + 1
      }
      if expected_status == "ambiguous_source" {
        ambiguity_expected = ambiguity_expected + 1
      }
      if expected_status == "conflict" {
        conflict_expected = conflict_expected + 1
      }
      if expected_status == "missing_source" {
        missing_expected = missing_expected + 1
      }
      if report_has_core_match(report, expected) {
        engine_value_correct = engine_value_correct + 1
      }
      if report_has_full_match(report, expected) {
        engine_full_correct = engine_full_correct + 1
        if expected_evidence.length() > 0 {
          engine_evidence_correct = engine_evidence_correct + 1
        }
      }
      if baseline_value_correct(document, claims_json, expected) {
        baseline_value_correct_count = baseline_value_correct_count + 1
      }
      if baseline_full_correct(document, claims_json, expected) {
        baseline_full_correct_count = baseline_full_correct_count + 1
        if expected_evidence.length() > 0 {
          baseline_evidence_correct = baseline_evidence_correct + 1
        }
      }
    }
    let mut diagnostics_expected = 0
    let mut diagnostics_detected = 0
    for diagnostic_json in expected_diagnostics_json {
      let diagnostic = match diagnostic_json {
        Object(diagnostic) => diagnostic
        _ => return Err("expected diagnostic must be an object: " + id)
      }
      diagnostics_expected = diagnostics_expected + 1
      if has_diagnostic(
          report,
          expected_value(diagnostic, "code"),
          expected_value(diagnostic, "field"),
        ) {
        diagnostics_detected = diagnostics_detected + 1
      }
    }
    let false_positives = count_false_positives(report, expected_json)
    let false_negatives = expected_count - engine_value_correct
    let ambiguity_detected = result_status_count(report, "ambiguous_source")
    let conflict_detected = result_status_count(report, "conflict")
    let missing_detected = result_status_count(report, "missing_source")
    let diagnostics_unexpected = report.diagnostics().length() -
      diagnostics_detected
    engine_value_total = engine_value_total + engine_value_correct
    engine_evidence_total = engine_evidence_total + engine_evidence_correct
    engine_full_total = engine_full_total + engine_full_correct
    baseline_value_total = baseline_value_total + baseline_value_correct_count
    baseline_evidence_total = baseline_evidence_total +
      baseline_evidence_correct
    baseline_full_total = baseline_full_total + baseline_full_correct_count
    expected_total = expected_total + expected_count
    evidence_expected_total = evidence_expected_total + evidence_expected
    false_positive_total = false_positive_total + false_positives
    false_negative_total = false_negative_total + false_negatives
    ambiguity_expected_total = ambiguity_expected_total + ambiguity_expected
    ambiguity_detected_total = ambiguity_detected_total + ambiguity_detected
    conflict_expected_total = conflict_expected_total + conflict_expected
    conflict_detected_total = conflict_detected_total + conflict_detected
    missing_expected_total = missing_expected_total + missing_expected
    missing_detected_total = missing_detected_total + missing_detected
    diagnostics_expected_total = diagnostics_expected_total +
      diagnostics_expected
    diagnostics_detected_total = diagnostics_detected_total +
      diagnostics_detected
    diagnostics_unexpected_total = diagnostics_unexpected_total +
      diagnostics_unexpected
    emitted_claims_total = emitted_claims_total + emitted.val
    chunk_total = chunk_total + report.chunk_count()
    let observed_fields : Array[Json] = []
    for result in report.fields() {
      observed_fields.push(result.to_json())
    }
    case_summaries.push(
      Json::object({
        "case": Json::string(id),
        "engine": Json::object({
          "value_correct": Json::number(engine_value_correct.to_double()),
          "evidence_correct": Json::number(engine_evidence_correct.to_double()),
          "full_correct": Json::number(engine_full_correct.to_double()),
          "false_positives": Json::number(false_positives.to_double()),
          "false_negatives": Json::number(false_negatives.to_double()),
          "ambiguity_detected": Json::number(ambiguity_detected.to_double()),
          "conflict_detected": Json::number(conflict_detected.to_double()),
          "missing_detected": Json::number(missing_detected.to_double()),
          "value_verified": Json::number(
            consistency_count(report, "verified").to_double(),
          ),
          "value_unverified": Json::number(
            consistency_count(report, "unverified").to_double(),
          ),
          "value_mismatch": Json::number(
            consistency_count(report, "mismatch").to_double(),
          ),
          "diagnostics_expected": Json::number(diagnostics_expected.to_double()),
          "diagnostics_detected": Json::number(diagnostics_detected.to_double()),
          "diagnostics_unexpected": Json::number(
            diagnostics_unexpected.to_double(),
          ),
          "emitted_claims": Json::number(emitted.val.to_double()),
          "field_count": Json::number(report.fields().length().to_double()),
          "chunks": Json::number(report.chunk_count().to_double()),
          "fields": Json::array(observed_fields),
        }),
        "baseline": Json::object({
          "value_correct": Json::number(
            baseline_value_correct_count.to_double(),
          ),
          "evidence_correct": Json::number(
            baseline_evidence_correct.to_double(),
          ),
          "full_correct": Json::number(baseline_full_correct_count.to_double()),
        }),
        "expected": Json::object({
          "fields": Json::number(expected_count.to_double()),
          "with_evidence": Json::number(evidence_expected.to_double()),
          "ambiguous": Json::number(ambiguity_expected.to_double()),
          "conflict": Json::number(conflict_expected.to_double()),
          "missing_source": Json::number(missing_expected.to_double()),
          "diagnostics": Json::number(diagnostics_expected.to_double()),
        }),
      }),
    )
  }
  Ok(
    Json::object({
      "scenario": Json::string(scenario),
      "model_mode": Json::string("recorded_chunk_filtered"),
      "cases": Json::array(case_summaries),
      "summary": Json::object({
        "engine": Json::object({
          "value_correct": Json::number(engine_value_total.to_double()),
          "evidence_correct": Json::number(engine_evidence_total.to_double()),
          "full_correct": Json::number(engine_full_total.to_double()),
          "value_accuracy": Json::number(
            ratio(engine_value_total, expected_total),
          ),
          "evidence_accuracy": Json::number(
            ratio(engine_evidence_total, evidence_expected_total),
          ),
          "full_accuracy": Json::number(
            ratio(engine_full_total, expected_total),
          ),
          "false_positives": Json::number(false_positive_total.to_double()),
          "false_negatives": Json::number(false_negative_total.to_double()),
          "ambiguity_expected": Json::number(
            ambiguity_expected_total.to_double(),
          ),
          "ambiguity_detected": Json::number(
            ambiguity_detected_total.to_double(),
          ),
          "conflict_expected": Json::number(conflict_expected_total.to_double()),
          "conflict_detected": Json::number(conflict_detected_total.to_double()),
          "missing_expected": Json::number(missing_expected_total.to_double()),
          "missing_detected": Json::number(missing_detected_total.to_double()),
          "diagnostics_expected": Json::number(
            diagnostics_expected_total.to_double(),
          ),
          "diagnostics_detected": Json::number(
            diagnostics_detected_total.to_double(),
          ),
          "diagnostics_unexpected": Json::number(
            diagnostics_unexpected_total.to_double(),
          ),
          "emitted_claims": Json::number(emitted_claims_total.to_double()),
          "chunks": Json::number(chunk_total.to_double()),
        }),
        "baseline": Json::object({
          "value_correct": Json::number(baseline_value_total.to_double()),
          "evidence_correct": Json::number(baseline_evidence_total.to_double()),
          "full_correct": Json::number(baseline_full_total.to_double()),
          "value_accuracy": Json::number(
            ratio(baseline_value_total, expected_total),
          ),
          "evidence_accuracy": Json::number(
            ratio(baseline_evidence_total, evidence_expected_total),
          ),
          "full_accuracy": Json::number(
            ratio(baseline_full_total, expected_total),
          ),
        }),
        "expected": Json::object({
          "fields": Json::number(expected_total.to_double()),
          "with_evidence": Json::number(evidence_expected_total.to_double()),
        }),
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
  println(Json::array(results).stringify(indent=2))
}
