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
  import Foundation
  import Testing

  @testable import FoundationModelsFake

  /// Tests for building `GeneratedContent` with its initializers.
  @Suite("GeneratedContent construction")
  struct GeneratedContentConstructionTests {
    @Test
    func nestedContentInheritsTopLevelID() throws {
      let id = GenerationID()
      let content = GeneratedContent(
        properties: ["a": GeneratedContent("x", id: GenerationID()), "b": [1]],
        id: id
      )

      guard case .structure(let properties, _) = content.kind else {
        Issue.record("Expected a structure")
        return
      }
      let nested = try #require(properties["b"])
      guard case .array(let elements) = nested.kind else {
        Issue.record("Expected an array")
        return
      }

      #expect(properties["a"]?.id == id)
      #expect(nested.id == id)
      #expect(elements.map(\.id) == [id])
      #expect(try content.value(GeneratedContent.self, forProperty: "a").id == id)
    }

    @Test
    func uniquingKeysRethrows() {
      struct Failure: Error {}

      #expect(throws: Failure.self) {
        try GeneratedContent(
          properties: [("a", 1 as any ConvertibleToGeneratedContent), ("a", 2)],
          uniquingKeysWith: {
            (_: GeneratedContent, _: GeneratedContent) throws -> GeneratedContent in
            throw Failure()
          }
        )
      }
    }

    @Test
    func constructedContainersAreCompleteOnlyWhenTheirChildrenAre() throws {
      let partial = try GeneratedContent(json: #""Al"#)

      let structure = GeneratedContent(properties: ["name": partial])
      let array = GeneratedContent(elements: [partial, "x"] as [any ConvertibleToGeneratedContent])
      let complete = GeneratedContent(properties: ["name": "Al"])

      #expect(!partial.isComplete)
      #expect(!structure.isComplete)
      #expect(!array.isComplete)
      #expect(complete.isComplete)
    }
  }
#endif  // compiler(>=6.4)
