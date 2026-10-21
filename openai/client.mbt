///|
/// Configuration for an OpenAI-compatible chat-completions endpoint.
pub struct OpenAIConfig {
  priv api_key : String
  priv base_url : String
  priv model : String
}

///|
pub fn OpenAIConfig::new(
  api_key~ : String,
  model~ : String,
  base_url~ : String = "https://api.openai.com/v1",
) -> OpenAIConfig {
  { api_key, base_url, model, }
}

///|
fn OpenAIConfig::api_key(self : OpenAIConfig) -> String {
  self.api_key
}

///|
pub fn OpenAIConfig::base_url(self : OpenAIConfig) -> String {
  self.base_url
}

///|
pub fn OpenAIConfig::model(self : OpenAIConfig) -> String {
  self.model
}

///|
/// Complete one prompt through an OpenAI-compatible chat endpoint.
///
/// This adapter is intentionally thin. Prompt construction, response parsing,
/// evidence resolution, conflict handling, and chunk merging remain in the
/// engine package. That separation lets the same engine run against a live
/// model, a recorded model, or a test double.
pub async fn complete(
  config : OpenAIConfig,
  prompt : @engine.Prompt,
) -> Result[String, String] {
  let transport = @http_async.AsyncTransport::new(
    timeout_ms=600_000,
    connect_timeout_ms=5_000,
    max_body_bytes=64 * 1024 * 1024,
  )
  let clock = @http_async.AsyncClock::new()
  let timer = @http_async.ClockTimer::new()
  let client = @provider.OpenAI::new(
    api_key=config.api_key(),
    transport,
    clock,
    base_url=config.base_url(),
    timer~,
    timeout_ms=600_000,
  )
  let request = @provider.ChatRequest::new(
    model=config.model(),
    messages=[
      @provider.ChatMessage::system(prompt.system()),
      @provider.ChatMessage::user(prompt.user()),
    ],
    temperature=0.0,
  )
  let response = client.chat_completion(request) catch {
    error => {
      let message = match @provider.api_error(error) {
        Some(body) => body.message
        None => "OpenAI-compatible request failed"
      }
      return Err(message)
    }
  }
  if response.text.is_blank() {
    return Err("model returned an empty response")
  }
  Ok(response.text)
}
