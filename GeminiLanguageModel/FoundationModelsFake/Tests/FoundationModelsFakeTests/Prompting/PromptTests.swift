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

#if compiler(>=6.4)
  import Testing

  @testable import FoundationModelsFake

  #if canImport(FoundationEssentials)
    import FoundationEssentials
  #else
    import Foundation
  #endif

  @Suite("Prompt Tests")
  struct PromptTests {
    @Test
    func emptyPrompt() {
      let prompt = Prompt()

      #expect(prompt.components.isEmpty)
      #expect(prompt.segments.isEmpty)
    }

    @Test
    func stringPromptRepresentation() {
      let text = "Hello"

      let prompt = text.promptRepresentation

      #expect(prompt.components.count == 1)
      guard case .text(let t) = prompt.components.first else {
        Issue.record("Expected text component")
        return
      }
      #expect(t.value == "Hello")
      #expect(prompt.segments.count == 1)
      guard case .text(let seg) = prompt.segments.first else {
        Issue.record("Expected text segment")
        return
      }
      #expect(seg.content == "Hello")
    }

    @Test
    func emptyStringPromptRepresentation() {
      let text = ""

      let prompt = text.promptRepresentation

      #expect(prompt.components.count == 1)
      guard case .text(let t) = prompt.components.first else {
        Issue.record("Expected text component")
        return
      }
      #expect(t.value == "")
      #expect(prompt.segments.count == 1)
      guard case .text(let seg) = prompt.segments.first else {
        Issue.record("Expected text segment")
        return
      }
      #expect(seg.content == "")
    }

    @Test
    func promptBuilderEmptyString() {
      let prompt = Prompt {
        ""
      }

      #expect(prompt.components.count == 1)
      #expect(prompt.segments.count == 1)
      guard case .text(let seg) = prompt.segments.first else {
        Issue.record("Expected text segment")
        return
      }
      #expect(seg.content == "")
    }

    @Test
    func promptBuilderTwoStringsFixture() {
      let prompt = Prompt {
        "First line"
        "Second line"
      }

      #expect(prompt.components.count == 2)
      #expect(prompt.segments.count == 2)
      guard case .text(let seg1) = prompt.segments[0],
        case .text(let seg2) = prompt.segments[1]
      else {
        Issue.record("Expected text segments")
        return
      }
      #expect(seg1.content == "First line")
      #expect(seg2.content == "Second line")
    }

    @Test
    func promptBuilderArrayFixture() {
      let items = ["a", "b", "c"]
      let prompt = Prompt {
        items
      }

      #expect(prompt.components.count == 3)
      #expect(prompt.segments.count == 3)
      let texts = prompt.segments.compactMap { seg -> String? in
        guard case .text(let t) = seg else { return nil }
        return t.content
      }
      #expect(texts == ["a", "b", "c"])
    }

    @Test
    func promptBuilderIfTrueFixture() {
      let condition = true
      let prompt = Prompt {
        if condition {
          "true branch"
        }
      }

      #expect(prompt.components.count == 1)
      #expect(prompt.segments.count == 1)
      guard case .text(let seg) = prompt.segments.first else {
        Issue.record("Expected text segment")
        return
      }
      #expect(seg.content == "true branch")
    }

    @Test
    func promptBuilderOptionalNilFixture() {
      let opt: String? = nil
      let prompt = Prompt {
        "before"
        if let text = opt {
          text
        }
        "after"
      }

      #expect(prompt.components.count == 2)
      #expect(prompt.segments.count == 2)
      guard case .text(let seg1) = prompt.segments[0],
        case .text(let seg2) = prompt.segments[1]
      else {
        Issue.record("Expected text segments")
        return
      }
      #expect(seg1.content == "before")
      #expect(seg2.content == "after")
    }

    @Test
    func promptBuilderNestedFixture() {
      let prompt = Prompt {
        Prompt {
          "inner"
        }
        "outer"
      }

      #expect(prompt.components.count == 2)
      #expect(prompt.segments.count == 2)
      guard case .text(let seg1) = prompt.segments[0],
        case .text(let seg2) = prompt.segments[1]
      else {
        Issue.record("Expected text segments")
        return
      }
      #expect(seg1.content == "inner")
      #expect(seg2.content == "outer")
    }

    @Test
    func promptBuilderAttachmentFixture() throws {
      let url = try #require(URL(string: "https://example.com/photo.jpg"))
      let prompt = Prompt {
        "Look:"
        Attachment(imageURL: url).label("photo")
      }

      #expect(prompt.components.count == 2)
      #expect(prompt.segments.count == 2)
      guard case .text(let tSeg) = prompt.segments[0],
        case .attachment(let aSeg) = prompt.segments[1]
      else {
        Issue.record("Expected text and attachment segments")
        return
      }
      #expect(tSeg.content == "Look:")
      #expect(aSeg.label == "photo")
      guard case .image(let img) = aSeg.content else {
        Issue.record("Expected image attachment")
        return
      }
      #expect(img.url == url)
    }

    @Test
    func promptPromptRepresentationIdentity() {
      let original = Prompt {
        "Self check"
      }

      let represented = original.promptRepresentation

      #expect(represented.components == original.components)
    }
  }
#endif  // compiler(>=6.4)
