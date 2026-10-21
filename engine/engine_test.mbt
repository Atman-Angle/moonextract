///|
fn engine_test_document(
  id : String,
  text : String,
) -> @moonextract.Document raise {
  match @moonextract.Document::new(id, text) {
    Ok(document) => document
    Err(_) => fail("test document should be valid")
  }
}

///|
fn engine_test_report(
  document : @moonextract.Document,
  fields : Array[@engine.FieldDefinition],
  claims : Array[@engine.LlmClaim],
) -> @engine.ExtractionReport raise {
  match @engine.resolve_claims(document, fields, claims, 1) {
    Ok(report) => report
    Err(_) => fail("claims should resolve")
  }
}

///|
test "parse_model_output accepts a fenced claims object" {
  let output = "```json\n{\"claims\":[{\"field\":\"party\",\"value\":\"晨星\",\"quote\":\"晨星\",\"context\":\"甲方\"}]}\n```"
  let claims = match @engine.parse_model_output(output) {
    Ok(claims) => claims
    Err(_) => fail("fenced JSON should parse")
  }
  assert_eq(claims.length(), 1)
  assert_eq(claims[0].field(), "party")
  assert_eq(claims[0].value(), "晨星")
  assert_eq(claims[0].quote(), "晨星")
  assert_eq(claims[0].context(), Some("甲方"))
}

///|
test "build_prompt includes field descriptions and quote contract" {
  let prompt = @engine.build_prompt(
    [
      @engine.FieldDefinition::new(name="party", description="合同签约方"),
      @engine.FieldDefinition::new(
        name="amount",
        description="合同金额",
        required=false,
      ),
    ],
    "甲方：晨星",
  )
  assert_true(prompt.system().contains("quote must be copied verbatim"))
  assert_true(prompt.user().contains("party"))
  assert_true(prompt.user().contains("合同金额"))
  assert_true(prompt.user().contains("甲方：晨星"))
}

///|
test "context disambiguates repeated source text" {
  let document = engine_test_document(
    "contract", "甲方：晨星\n乙方：晨星",
  )
  let fields = [
    @engine.FieldDefinition::new(name="party", description="签约方"),
  ]
  let claims = [
    @engine.LlmClaim::new(
      field="party",
      value="晨星",
      quote="晨星",
      context="乙方",
    ),
  ]
  let report = engine_test_report(document, fields, claims)
  assert_eq(report.fields().length(), 1)
  match report.fields()[0].status() {
    @engine.FieldStatus::Resolved => ()
    _ => fail("context should resolve the repeated quote")
  }
  assert_eq(report.fields()[0].evidence().length(), 1)
  assert_eq(report.fields()[0].evidence()[0].span().start(), 9)
  assert_eq(report.fields()[0].evidence()[0].span().end(), 11)
}

///|
test "missing context leaves repeated source ambiguous" {
  let document = engine_test_document(
    "contract", "甲方：晨星\n乙方：晨星",
  )
  let fields = [
    @engine.FieldDefinition::new(name="party", description="签约方"),
  ]
  let claims = [
    @engine.LlmClaim::new(field="party", value="晨星", quote="晨星"),
  ]
  let report = engine_test_report(document, fields, claims)
  match report.fields()[0].status() {
    @engine.FieldStatus::AmbiguousSource => ()
    _ => fail("repeated quote should remain ambiguous")
  }
  assert_eq(report.fields()[0].evidence().length(), 2)
  assert_eq(report.diagnostics().length(), 1)
  match report.diagnostics()[0] {
    @engine.Diagnostic::AmbiguousSource("party", "晨星", 2) => ()
    _ => fail("ambiguous source diagnostic should be emitted")
  }
}

///|
test "missing quote is not replaced by the field value" {
  let document = engine_test_document("contract", "甲方：晨星")
  let fields = [
    @engine.FieldDefinition::new(name="party", description="签约方"),
  ]
  let claims = [
    @engine.LlmClaim::new(
      field="party",
      value="晨星",
      quote="不存在的原文",
    ),
  ]
  let report = engine_test_report(document, fields, claims)
  match report.fields()[0].status() {
    @engine.FieldStatus::MissingSource => ()
    _ => fail("missing quote must not use value as evidence")
  }
  assert_eq(report.fields()[0].evidence().length(), 0)
  match report.diagnostics()[0] {
    @engine.Diagnostic::MissingSource("party", "不存在的原文") => ()
    _ => fail("missing source diagnostic should be emitted")
  }
}

///|
test "non-repeatable field conflict is explicit" {
  let document = engine_test_document(
    "contract", "初审金额：100 元\n终审金额：120 元",
  )
  let fields = [
    @engine.FieldDefinition::new(name="amount", description="金额"),
  ]
  let claims = [
    @engine.LlmClaim::new(field="amount", value="100 元", quote="100 元"),
    @engine.LlmClaim::new(field="amount", value="120 元", quote="120 元"),
  ]
  let report = engine_test_report(document, fields, claims)
  assert_eq(report.fields().length(), 2)
  match report.fields()[0].status() {
    @engine.FieldStatus::Conflict => ()
    _ => fail("conflicting amount should be marked")
  }
  match report.diagnostics()[0] {
    @engine.Diagnostic::FieldConflict("amount", values) =>
      assert_eq(values.length(), 2)
    _ => fail("field conflict diagnostic should be emitted")
  }
}

///|
test "repeatable field preserves multiple evidence records" {
  let document = engine_test_document(
    "contract", "甲方：晨星\n乙方：远山",
  )
  let fields = [
    @engine.FieldDefinition::new(
      name="party",
      description="签约方",
      repeatable=true,
    ),
  ]
  let claims = [
    @engine.LlmClaim::new(
      field="party",
      value="晨星",
      quote="晨星",
      context="甲方",
    ),
    @engine.LlmClaim::new(
      field="party",
      value="远山",
      quote="远山",
      context="乙方",
    ),
  ]
  let report = engine_test_report(document, fields, claims)
  assert_eq(report.fields().length(), 2)
  match report.fields()[0].status() {
    @engine.FieldStatus::Resolved => ()
    _ => fail("first party should resolve")
  }
  match report.fields()[1].status() {
    @engine.FieldStatus::Resolved => ()
    _ => fail("second party should resolve")
  }
  assert_eq(report.fields()[0].value(), "晨星")
  assert_eq(report.fields()[0].quote(), "晨星")
}

///|
test "required field without a claim is diagnosed" {
  let document = engine_test_document("contract", "甲方：晨星")
  let fields = [
    @engine.FieldDefinition::new(name="party", description="签约方"),
    @engine.FieldDefinition::new(name="amount", description="金额"),
  ]
  let claims = [
    @engine.LlmClaim::new(field="party", value="晨星", quote="晨星"),
  ]
  let report = engine_test_report(document, fields, claims)
  let mut found = false
  for diagnostic in report.diagnostics() {
    match diagnostic {
      @engine.Diagnostic::MissingRequiredField("amount") => found = true
      _ => ()
    }
  }
  assert_true(found)
}

///|
test "normalized value and verbatim quote remain separate" {
  let document = engine_test_document("contract", "金额：120,000 元")
  let fields = [
    @engine.FieldDefinition::new(name="amount", description="金额"),
  ]
  let claims = [
    @engine.LlmClaim::new(
      field="amount",
      value="120000 元",
      quote="120,000 元",
    ),
  ]
  let report = engine_test_report(document, fields, claims)
  assert_eq(report.fields()[0].value(), "120000 元")
  assert_eq(report.fields()[0].quote(), "120,000 元")
  assert_eq(report.fields()[0].evidence()[0].text(), "120,000 元")
}

///|
test "numeric values normalize separators and units" {
  assert_eq(@engine.normalize_number("120,000 元"), Some("120000"))
  assert_eq(@engine.normalize_number("120000元"), Some("120000"))
  assert_eq(@engine.normalize_number("30 日"), Some("30"))
  assert_eq(@engine.normalize_number("abc"), None)
}

///|
test "numeric mismatch is explicit even when quote exists" {
  let document = engine_test_document(
    "contract", "合同总金额：120,000 元",
  )
  let fields = [
    @engine.FieldDefinition::new(
      name="amount",
      description="合同金额",
      value_kind=@engine.FieldValueKind::Number,
    ),
  ]
  let claims = [
    @engine.LlmClaim::new(
      field="amount",
      value="999999 元",
      quote="120,000 元",
    ),
  ]
  let report = engine_test_report(document, fields, claims)
  match report.fields()[0].status() {
    @engine.FieldStatus::Resolved => ()
    _ => fail("the quote itself is resolved")
  }
  match report.fields()[0].value_consistency() {
    @engine.ValueConsistency::Mismatch => ()
    _ => fail("numeric consistency should be mismatch")
  }
  match report.diagnostics()[0] {
    @engine.Diagnostic::ValueMismatch("amount", "999999 元", "120,000 元") =>
      ()
    _ => fail("numeric mismatch should be diagnosed")
  }
}

///|
test "source chunk prevents binding to a global duplicate" {
  let document = engine_test_document("duplicate", "晨星\n---\n晨星")
  let source = @engine.ClaimSource::new(index=0, start=0, end=5)
  let fields = [
    @engine.FieldDefinition::new(name="party", description="签约方"),
  ]
  let claims = [
    @engine.LlmClaim::new(
      field="party",
      value="晨星",
      quote="晨星",
      source~,
    ),
  ]
  let report = engine_test_report(document, fields, claims)
  match report.fields()[0].status() {
    @engine.FieldStatus::Resolved => ()
    _ => fail("claim should resolve inside its source chunk")
  }
  assert_eq(report.fields()[0].evidence()[0].span().start(), 0)
  assert_eq(report.fields()[0].source_chunk().unwrap().index(), 0)
}

///|
test "claim outside its source chunk is rejected" {
  let document = engine_test_document("duplicate", "晨星\n---\n晨星")
  let source = @engine.ClaimSource::new(index=1, start=2, end=5)
  let fields = [
    @engine.FieldDefinition::new(name="party", description="签约方"),
  ]
  let claims = [
    @engine.LlmClaim::new(
      field="party",
      value="晨星",
      quote="晨星",
      source~,
    ),
  ]
  let report = engine_test_report(document, fields, claims)
  match report.fields()[0].status() {
    @engine.FieldStatus::MissingSource => ()
    _ => fail("claim must not bind outside its source chunk")
  }
  match report.diagnostics()[0] {
    @engine.Diagnostic::SourceOutsideChunk("party", "晨星", 1) => ()
    _ => fail("source-outside-chunk diagnostic should be emitted")
  }
}

///|
test "unknown claim field is diagnosed without creating a result" {
  let document = engine_test_document("contract", "甲方：晨星")
  let fields = [
    @engine.FieldDefinition::new(name="party", description="签约方"),
  ]
  let claims = [
    @engine.LlmClaim::new(
      field="billing_address",
      value="晨星",
      quote="晨星",
    ),
  ]
  let report = engine_test_report(document, fields, claims)
  assert_eq(report.fields().length(), 0)
  match report.diagnostics()[0] {
    @engine.Diagnostic::UnknownField("billing_address") => ()
    _ => fail("unknown field should be diagnosed")
  }
}

///|
test "text value that cannot be proven is marked unverified" {
  let document = engine_test_document("ticket", "根因：证书过期")
  let fields = [
    @engine.FieldDefinition::new(name="root_cause", description="根因"),
  ]
  let claims = [
    @engine.LlmClaim::new(
      field="root_cause",
      value="TLS 证书过期",
      quote="证书过期",
    ),
  ]
  let report = engine_test_report(document, fields, claims)
  match report.fields()[0].value_consistency() {
    @engine.ValueConsistency::Unverified => ()
    _ => fail("text consistency should be unverified")
  }
  match report.diagnostics()[0] {
    @engine.Diagnostic::ValueUnverified(
      "root_cause",
      "TLS 证书过期",
      "证书过期"
    ) => ()
    _ => fail("text value should be marked unverified")
  }
}

///|
test "overlapping chunk resolves a boundary-crossing quote" {
  let document = engine_test_document("boundary", "0123456789ABCDE")
  let source = @engine.ClaimSource::new(index=1, start=7, end=17)
  let fields = [@engine.FieldDefinition::new(name="code", description="编码")]
  let claims = [
    @engine.LlmClaim::new(field="code", value="89AB", quote="89AB", source~),
  ]
  let report = engine_test_report(document, fields, claims)
  match report.fields()[0].status() {
    @engine.FieldStatus::Resolved => ()
    _ => fail("overlap should contain the complete quote")
  }
  assert_eq(report.fields()[0].evidence()[0].span().start(), 8)
  assert_eq(report.fields()[0].evidence()[0].span().end(), 12)
}

///|
test "overlapping chunks deduplicate the same resolved evidence" {
  let document = engine_test_document("duplicate", "晨星\n---\n晨星")
  let fields = [
    @engine.FieldDefinition::new(name="party", description="签约方"),
  ]
  let claims = [
    @engine.LlmClaim::new(
      field="party",
      value="晨星",
      quote="晨星",
      source=@engine.ClaimSource::new(index=0, start=0, end=5),
    ),
    @engine.LlmClaim::new(
      field="party",
      value="晨星",
      quote="晨星",
      source=@engine.ClaimSource::new(index=1, start=0, end=5),
    ),
  ]
  let report = engine_test_report(document, fields, claims)
  assert_eq(report.fields().length(), 1)
  assert_eq(report.fields()[0].evidence().length(), 1)
}
