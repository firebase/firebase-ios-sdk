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
import HTTPStreamingClient
import Testing

@Suite("HTTPLineDecoder Tests")
struct HTTPLineDecoderTests {
  @Test
  func singleChunkWithMultipleLines() {
    var decoder = HTTPLineDecoder()
    let data = Data("line1\nline2\nline3\n".utf8)

    let lines = decoder.feed(data)
    let remainder = decoder.flush()

    #expect(lines == ["line1", "line2", "line3"])
    #expect(remainder == nil)
  }

  @Test
  func linesSplitAcrossMultipleChunks() {
    var decoder = HTTPLineDecoder()
    let chunk1 = Data("hello ".utf8)
    let chunk2 = Data("world\nsecond ".utf8)
    let chunk3 = Data("line\n".utf8)

    let lines1 = decoder.feed(chunk1)
    let lines2 = decoder.feed(chunk2)
    let lines3 = decoder.feed(chunk3)
    let remainder = decoder.flush()

    #expect(lines1.isEmpty)
    #expect(lines2 == ["hello world"])
    #expect(lines3 == ["second line"])
    #expect(remainder == nil)
  }

  @Test
  func splitCRLFBoundary() {
    var decoder = HTTPLineDecoder()
    let chunk1 = Data("first\r".utf8)
    let chunk2 = Data("\nsecond\r\n".utf8)

    let lines1 = decoder.feed(chunk1)
    let lines2 = decoder.feed(chunk2)
    let remainder = decoder.flush()

    #expect(lines1 == ["first"])
    #expect(lines2 == ["second"])
    #expect(remainder == nil)
  }

  @Test
  func standaloneCarriageReturn() {
    var decoder = HTTPLineDecoder()
    let chunk1 = Data("first\r".utf8)
    let chunk2 = Data("second\r".utf8)
    let chunk3 = Data("third".utf8)

    let lines1 = decoder.feed(chunk1)
    let lines2 = decoder.feed(chunk2)
    let lines3 = decoder.feed(chunk3)
    let remainder = decoder.flush()

    #expect(lines1 == ["first"])
    #expect(lines2 == ["second"])
    #expect(lines3.isEmpty)
    #expect(remainder == "third")
  }

  @Test
  func splitMultiByteUTF8Character() {
    var decoder = HTTPLineDecoder()
    // "🎉" is 4 bytes: 0xF0, 0x9F, 0x8E, 0x89
    let emojiBytes: [UInt8] = [0xF0, 0x9F, 0x8E, 0x89]
    let chunk1 = Data("Start ".utf8) + Data(emojiBytes[0..<2])
    let chunk2 = Data(emojiBytes[2..<4]) + Data(" End\n".utf8)

    let lines1 = decoder.feed(chunk1)
    let lines2 = decoder.feed(chunk2)
    let remainder = decoder.flush()

    #expect(lines1.isEmpty)
    #expect(lines2 == ["Start 🎉 End"])
    #expect(remainder == nil)
  }

  @Test
  func preserveBlankLines() {
    var decoder = HTTPLineDecoder()
    let data = Data("line1\n\nline2\r\n\r\nline3\n".utf8)

    let lines = decoder.feed(data)
    let remainder = decoder.flush()

    #expect(lines == ["line1", "", "line2", "", "line3"])
    #expect(remainder == nil)
  }

  @Test
  func flushRemainderWithoutTrailingNewline() {
    var decoder = HTTPLineDecoder()
    let data = Data("no newline at end".utf8)

    let lines = decoder.feed(data)
    let remainder = decoder.flush()

    #expect(lines.isEmpty)
    #expect(remainder == "no newline at end")
  }
}
