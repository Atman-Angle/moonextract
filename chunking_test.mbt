///|
fn chunking_test_document(
  id : String,
  text : String,
) -> @moonextract.Document raise {
  match @moonextract.Document::new(id, text) {
    Ok(document) => document
    Err(_) => fail("test document should be valid")
  }
}

///|
test "chunks split emoji text by code point and keep global offsets" {
  let document = chunking_test_document("manual", "A😀中BC")
  match document.chunks(2) {
    Ok(chunks) => {
      assert_eq(chunks.length(), 3)
      assert_eq(chunks[0].index(), 0)
      assert_eq(chunks[0].start(), 0)
      assert_eq(chunks[0].end(), 2)
      assert_eq(chunks[0].text(), "A😀")
      assert_eq(chunks[1].start(), 2)
      assert_eq(chunks[1].end(), 4)
      assert_eq(chunks[1].text(), "中B")
      assert_eq(chunks[2].start(), 4)
      assert_eq(chunks[2].end(), 5)
      assert_eq(chunks[2].text(), "C")
    }
    Err(_) => fail("valid chunk size should succeed")
  }
}

///|
test "chunks map local spans back to global coordinates" {
  let document = chunking_test_document("manual", "A😀中BC")
  match document.chunks(2) {
    Ok(chunks) =>
      match chunks[1].to_global(1, 2) {
        Ok(span) => {
          assert_eq(span.start(), 3)
          assert_eq(span.end(), 4)
        }
        Err(_) => fail("valid local span should map")
      }
    Err(_) => fail("chunking should succeed")
  }
}

///|
test "overlapping chunks preserve boundary context" {
  let document = chunking_test_document("long", "abcdefghij")
  match document.chunks_with_overlap(6, 2) {
    Ok(chunks) => {
      assert_eq(chunks.length(), 2)
      assert_eq(chunks[0].text(), "abcdef")
      assert_eq(chunks[1].text(), "efghij")
      assert_eq(chunks[1].start(), 4)
      assert_eq(chunks[1].end(), 10)
    }
    Err(_) => fail("overlapping chunks should succeed")
  }
}

///|
test "chunks reject invalid sizes and local spans" {
  let document = chunking_test_document("text", "text")
  match document.chunks(0) {
    Err(@moonextract.ChunkError::InvalidChunkSize(0)) => ()
    _ => fail("zero chunk size must be rejected")
  }
  match document.chunks_with_overlap(4, 4) {
    Err(@moonextract.ChunkError::InvalidOverlap(4, 4)) => ()
    _ => fail("overlap equal to chunk size must be rejected")
  }
  match document.chunks(2) {
    Ok(chunks) =>
      match chunks[0].to_global(1, 3) {
        Err(@moonextract.ChunkError::LocalSpanOutOfBounds(1, 3, 2)) => ()
        _ => fail("local span must stay inside chunk")
      }
    Err(_) => fail("chunking should succeed")
  }
}

///|
test "empty document produces no chunks" {
  let document = chunking_test_document("empty", "")
  match document.chunks(10) {
    Ok(chunks) => assert_eq(chunks.length(), 0)
    Err(_) => fail("empty document should chunk successfully")
  }
}
