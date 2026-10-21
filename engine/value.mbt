///|
/// Normalize a numeric field value for consistency checks.
///
/// This is intentionally narrow. It accepts ASCII digits, an optional leading
/// sign, one decimal point, thousands separators, whitespace, and a small set
/// of common currency and duration decorations. Other text is rejected instead
/// of being silently converted into a number.
pub fn normalize_number(value : String) -> String? {
  let chars = value.to_array()
  let output : Array[Char] = []
  let mut seen_digit = false
  let mut seen_dot = false
  let mut seen_sign = false
  for char in chars {
    if char.is_ascii_digit() {
      output.push(char)
      seen_digit = true
    } else if (char == '-' || char == '+') && output.length() == 0 && !seen_sign {
      if char == '-' {
        output.push(char)
      }
      seen_sign = true
    } else if char == '.' && !seen_dot {
      output.push(char)
      seen_dot = true
    } else if char.is_whitespace() ||
      char == ',' ||
      char == '元' ||
      char == '￥' ||
      char == '¥' ||
      char == '$' ||
      char == '€' ||
      char == '日' ||
      char == '天' ||
      char == '%' {
      ()
    } else {
      return None
    }
  }
  if !seen_digit || output.length() == 0 {
    return None
  }
  if output[0] == '.' || output[output.length() - 1] == '.' {
    return None
  }
  if output.length() == 1 && (output[0] == '-' || output[0] == '+') {
    return None
  }
  Some(String::from_array(output))
}

///|
/// Compare a claim value with the verbatim evidence text under the field's
/// declared value policy.
pub fn verify_value(
  field : FieldDefinition,
  claim : LlmClaim,
  evidence : @moonextract.Evidence,
) -> ValueConsistency {
  match field.value_kind() {
    Text =>
      if @moonextract.normalize_whitespace(claim.value()) ==
        @moonextract.normalize_whitespace(evidence.text()) {
        Verified
      } else {
        Unverified
      }
    Number =>
      match
        (normalize_number(claim.value()), normalize_number(evidence.text())) {
        (Some(claim_number), Some(source_number)) =>
          if claim_number == source_number {
            Verified
          } else {
            Mismatch
          }
        _ => Unverified
      }
  }
}
