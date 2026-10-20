///|
/// A code-point range of a document produced by deterministic chunking.
pub(all) struct TextChunk {
  index : Int32
  start : Int32
  end : Int32
  text : String
}

///|
/// Recoverable errors raised while chunking or mapping local spans.
pub(all) suberror ChunkError {
  InvalidChunkSize(Int32)
  LocalSpanOutOfBounds(Int32, Int32, Int32)
}

///|
/// Split a document into consecutive chunks of at most `max_chars` code points.
///
/// Chunk offsets remain global code-point indices, so evidence located inside a
/// chunk can be mapped back without rewriting coordinates.
#warnings("-result_error_return")
pub fn Document::chunks(
  self : Document,
  max_chars : Int32,
) -> Result[Array[TextChunk], ChunkError] {
  if max_chars <= 0 {
    return Err(InvalidChunkSize(max_chars))
  }
  let chars = self.text.to_array()
  let length = chars.length()
  let chunks : Array[TextChunk] = []
  if length == 0 {
    return Ok(chunks)
  }
  let mut start = 0
  let mut index = 0
  while start < length {
    let mut end = start + max_chars
    if end > length {
      end = length
    }
    chunks.push(TextChunk::{
      index,
      start,
      end,
      text: String::from_array(chars[start:end]),
    })
    start = end
    index = index + 1
  }
  Ok(chunks)
}

///|
/// Translate a chunk-local code-point span into document-global coordinates.
#warnings("-result_error_return")
pub fn TextChunk::to_global(
  self : TextChunk,
  local_start : Int32,
  local_end : Int32,
) -> Result[Span, ChunkError] {
  let length = self.end - self.start
  if local_start < 0 || local_end < local_start || local_end > length {
    return Err(LocalSpanOutOfBounds(local_start, local_end, length))
  }
  Ok(Span::{ start: self.start + local_start, end: self.start + local_end, })
}
