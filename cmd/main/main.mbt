///|
fn print_usage() -> Unit {
  println("Usage: moon run cmd/main -- <text> <value> [field]")
  println("Without arguments, a built-in contract example is used.")
}

///|
fn run_demo(text : String, value : String, field : String) -> Unit {
  let document = match @moonextract.Document::new("demo", text) {
    Ok(document) => document
    Err(_) => {
      println("error: document id must not be blank")
      return
    }
  }
  let extraction = match document.extract_normalized(field, value) {
    Ok(extraction) => extraction
    Err(_) => {
      println("error: field and value must not be empty")
      return
    }
  }
  match @moonextract.validate_extraction(document, extraction) {
    Ok(_) => println(extraction.to_json_string(indent=2))
    Err(_) => println("error: extraction failed consistency validation")
  }
}

///|
fn main {
  let args = @env.args()
  if args.length() >= 2 && args[1] == "--help" {
    print_usage()
    return
  }
  if args.length() >= 3 {
    let field = if args.length() >= 4 { args[3] } else { "value" }
    run_demo(args[1], args[2], field)
    return
  }
  if args.length() == 2 {
    print_usage()
    return
  }
  run_demo(
    "合同编号：HT-001\n甲方：示例公司\n乙方：示例公司\n签署地：上海",
    "示例公司", "party",
  )
}
