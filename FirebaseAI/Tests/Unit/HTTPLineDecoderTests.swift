// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Testing

@testable import FirebaseAILogic

@Suite("HTTPLineDecoder Tests")
struct HTTPLineDecoderTests {
  @Test
  func singleChunkWithMultipleLines() throws {
    var decoder = HTTPLineDecoder()
    let data = Data("line1\nline2\nline3\n".utf8)

    let lines = try decoder.feed(data)
    let remainder = decoder.flush()

    #expect(lines == ["line1", "line2", "line3"])
    #expect(remainder == nil)
  }

  @Test
  func linesSplitAcrossMultipleChunks() throws {
    var decoder = HTTPLineDecoder()
    let chunk1 = Data("hello ".utf8)
    let chunk2 = Data("world\nsecond ".utf8)
    let chunk3 = Data("line\n".utf8)

    let lines1 = try decoder.feed(chunk1)
    let lines2 = try decoder.feed(chunk2)
    let lines3 = try decoder.feed(chunk3)
    let remainder = decoder.flush()

    #expect(lines1.isEmpty)
    #expect(lines2 == ["hello world"])
    #expect(lines3 == ["second line"])
    #expect(remainder == nil)
  }

  @Test
  func splitCRLFBoundary() throws {
    var decoder = HTTPLineDecoder()
    let chunk1 = Data("first\r".utf8)
    let chunk2 = Data("\nsecond\r\n".utf8)

    let lines1 = try decoder.feed(chunk1)
    let lines2 = try decoder.feed(chunk2)
    let remainder = decoder.flush()

    #expect(lines1 == ["first"])
    #expect(lines2 == ["second"])
    #expect(remainder == nil)
  }

  @Test
  func standaloneCarriageReturn() throws {
    var decoder = HTTPLineDecoder()
    let chunk1 = Data("first\r".utf8)
    let chunk2 = Data("second\r".utf8)
    let chunk3 = Data("third".utf8)

    let lines1 = try decoder.feed(chunk1)
    let lines2 = try decoder.feed(chunk2)
    let lines3 = try decoder.feed(chunk3)
    let remainder = decoder.flush()

    #expect(lines1 == ["first"])
    #expect(lines2 == ["second"])
    #expect(lines3.isEmpty)
    #expect(remainder == "third")
  }

  @Test
  func splitMultiByteUTF8Character() throws {
    var decoder = HTTPLineDecoder()
    // "🎉" is 4 bytes: 0xF0, 0x9F, 0x8E, 0x89
    let emojiBytes: [UInt8] = [0xF0, 0x9F, 0x8E, 0x89]
    let chunk1 = Data("Start ".utf8) + Data(emojiBytes[0 ..< 2])
    let chunk2 = Data(emojiBytes[2 ..< 4]) + Data(" End\n".utf8)

    let lines1 = try decoder.feed(chunk1)
    let lines2 = try decoder.feed(chunk2)
    let remainder = decoder.flush()

    #expect(lines1.isEmpty)
    #expect(lines2 == ["Start 🎉 End"])
    #expect(remainder == nil)
  }

  @Test
  func preserveBlankLines() throws {
    var decoder = HTTPLineDecoder()
    let data = Data("line1\n\nline2\r\n\r\nline3\n".utf8)

    let lines = try decoder.feed(data)
    let remainder = decoder.flush()

    #expect(lines == ["line1", "", "line2", "", "line3"])
    #expect(remainder == nil)
  }

  @Test
  func flushRemainderWithoutTrailingNewline() throws {
    var decoder = HTTPLineDecoder()
    let data = Data("no newline at end".utf8)

    let lines = try decoder.feed(data)
    let remainder = decoder.flush()

    #expect(lines.isEmpty)
    #expect(remainder == "no newline at end")
  }

  @Test
  func emptyDataReturnsNoLines() throws {
    var decoder = HTTPLineDecoder()

    let lines = try decoder.feed(Data())
    let remainder = decoder.flush()

    #expect(lines.isEmpty)
    #expect(remainder == nil)
  }

  @Test
  func multipleFlushesReturnNilAfterFirst() throws {
    var decoder = HTTPLineDecoder()
    _ = try decoder.feed(Data("trailing".utf8))

    let firstFlush = decoder.flush()
    let secondFlush = decoder.flush()

    #expect(firstFlush == "trailing")
    #expect(secondFlush == nil)
  }

  @Test
  func standaloneCRFollowedByNonNewlineChunk() throws {
    var decoder = HTTPLineDecoder()
    let chunk1 = Data("first\r".utf8)
    let chunk2 = Data("second\n".utf8)

    let lines1 = try decoder.feed(chunk1)
    let lines2 = try decoder.feed(chunk2)
    let remainder = decoder.flush()

    #expect(lines1 == ["first"])
    #expect(lines2 == ["second"])
    #expect(remainder == nil)
  }

  @Test
  func standaloneCRFollowedByNonNewlineInSameChunk() throws {
    var decoder = HTTPLineDecoder()
    let data = Data("first\rsecond\rthird\n".utf8)

    let lines = try decoder.feed(data)
    let remainder = decoder.flush()

    #expect(lines == ["first", "second", "third"])
    #expect(remainder == nil)
  }

  @Test
  func largePayloadWithMixedNewlines() throws {
    var decoder = HTTPLineDecoder()
    var expectedLines: [String] = []
    var combinedData = Data()

    for index in 1 ... 500 {
      let line = "Event item #\(index) with some UTF-8 data: 🚀✨"
      expectedLines.append(line)
      let delimiter = index.isMultiple(of: 2) ? "\r\n" : "\n"
      combinedData.append(Data("\(line)\(delimiter)".utf8))
    }

    let lines = try decoder.feed(combinedData)
    let remainder = decoder.flush()

    #expect(lines == expectedLines)
    #expect(remainder == nil)
  }

  @Test
  func doesNotSplitOnUnicodeLineSeparators() throws {
    var decoder = HTTPLineDecoder()
    let payload = "data: {\"text\": \"a\u{0085}b\u{2028}c\u{2029}d\"}"
    let data = Data("\(payload)\n".utf8)

    let lines = try decoder.feed(data)
    let remainder = decoder.flush()

    #expect(lines == [payload])
    #expect(remainder == nil)
  }

  @Test
  func defaultMaxLineLengthIs100MiB() {
    let decoder = HTTPLineDecoder()

    #expect(decoder.maxLineLength == 100 * 1024 * 1024)
  }

  @Test
  func lineAtMaxLengthIsAccepted() throws {
    var decoder = HTTPLineDecoder(maxLineLength: 5)

    let lines1 = try decoder.feed(Data("123".utf8))
    let lines2 = try decoder.feed(Data("45\r\n".utf8))

    #expect(lines1.isEmpty)
    #expect(lines2 == ["12345"])
  }

  @Test
  func completeLineExceedingMaxLengthThrows() throws {
    var decoder = HTTPLineDecoder(maxLineLength: 5)

    do {
      _ = try decoder.feed(Data("123456\n".utf8))
      Issue.record("Expected feed(_:) to throw URLError(.dataLengthExceedsMaximum)")
    } catch {
      let urlError = try #require(error as? URLError)
      #expect(urlError.code == .dataLengthExceedsMaximum)
    }
  }

  @Test
  func partialLineExceedingMaxLengthAcrossChunksThrowsAndReleasesBuffer() throws {
    var decoder = HTTPLineDecoder(maxLineLength: 5)
    _ = try decoder.feed(Data("123".utf8))

    do {
      _ = try decoder.feed(Data("456".utf8))
      Issue.record("Expected feed(_:) to throw URLError(.dataLengthExceedsMaximum)")
    } catch {
      let urlError = try #require(error as? URLError)
      #expect(urlError.code == .dataLengthExceedsMaximum)
    }
    let remainder = decoder.flush()

    #expect(remainder == nil)
  }
}
