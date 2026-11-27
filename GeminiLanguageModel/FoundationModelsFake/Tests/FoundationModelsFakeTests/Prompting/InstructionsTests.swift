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

  @Suite("Instructions Tests")
  struct InstructionsTests {
    @Test
    func emptyInstructions() {
      let instructions = Instructions()

      #expect(instructions.components.isEmpty)
      #expect(instructions.segments.isEmpty)
    }

    @Test
    func stringInstructionsRepresentation() {
      let text = "Be helpful."

      let instructions = text.instructionsRepresentation

      #expect(instructions.components.count == 1)
      guard case .text(let t) = instructions.components.first else {
        Issue.record("Expected text component")
        return
      }
      #expect(t.value == "Be helpful.")
      #expect(instructions.segments.count == 1)
      guard case .text(let seg) = instructions.segments.first else {
        Issue.record("Expected text segment")
        return
      }
      #expect(seg.content == "Be helpful.")
    }

    @Test
    func emptyStringInstructionsRepresentation() {
      let text = ""

      let instructions = text.instructionsRepresentation

      #expect(instructions.components.count == 1)
      #expect(instructions.segments.count == 1)
      guard case .text(let seg) = instructions.segments.first else {
        Issue.record("Expected text segment")
        return
      }
      #expect(seg.content == "")
    }

    @Test
    func instructionsBuilderTwoStringsFixture() {
      let instructions = Instructions {
        "Rule one."
        "Rule two."
      }

      #expect(instructions.components.count == 2)
      #expect(instructions.segments.count == 2)
      guard case .text(let s1) = instructions.segments[0],
        case .text(let s2) = instructions.segments[1]
      else {
        Issue.record("Expected text segments")
        return
      }
      #expect(s1.content == "Rule one.")
      #expect(s2.content == "Rule two.")
    }

    @Test
    func instructionsBuilderArrayFixture() {
      let rules = ["x", "y"]

      let instructions = Instructions {
        rules
      }

      #expect(instructions.components.count == 2)
      #expect(instructions.segments.count == 2)
      let texts = instructions.segments.compactMap { seg -> String? in
        guard case .text(let t) = seg else { return nil }
        return t.content
      }
      #expect(texts == ["x", "y"])
    }

    @Test
    func instructionsBuilderIfFixture() {
      let flag = true
      let instructions = Instructions {
        if flag {
          "yes"
        }
      }

      #expect(instructions.components.count == 1)
      #expect(instructions.segments.count == 1)
      guard case .text(let seg) = instructions.segments.first else {
        Issue.record("Expected text segment")
        return
      }
      #expect(seg.content == "yes")
    }

    @Test
    func instructionsBuilderNestedFixture() {
      let instructions = Instructions {
        Instructions {
          "inner"
        }
        "outer"
      }

      #expect(instructions.components.count == 2)
      #expect(instructions.segments.count == 2)
      guard case .text(let s1) = instructions.segments[0],
        case .text(let s2) = instructions.segments[1]
      else {
        Issue.record("Expected text segments")
        return
      }
      #expect(s1.content == "inner")
      #expect(s2.content == "outer")
    }

    @Test
    func instructionsBuilderOptionalFixture() {
      let extraRule: String? = nil
      let instructions = Instructions {
        "Rule A"
        if let rule = extraRule {
          rule
        }
        "Rule B"
      }

      #expect(instructions.components.count == 2)
      #expect(instructions.segments.count == 2)
      guard case .text(let s1) = instructions.segments[0],
        case .text(let s2) = instructions.segments[1]
      else {
        Issue.record("Expected text segments")
        return
      }
      #expect(s1.content == "Rule A")
      #expect(s2.content == "Rule B")
    }

    @Test
    func instructionsRepresentationIdentity() {
      let original = Instructions {
        "Base instruction"
      }

      let represented = original.instructionsRepresentation

      #expect(represented.components == original.components)
    }
  }
#endif  // compiler(>=6.4)
