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

  /// Tests for converting `GeneratedContent` to and from standard types.
  @Suite("GeneratedContent conversion")
  struct GeneratedContentConversionTests {
    @Test
    func conversionErrorsHaveAnErrorDescription() throws {
      let error = try #require(throws: GeneratedContent.ParsingError.self) {
        try GeneratedContent(12).value(String.self)
      }

      #expect(error.errorDescription?.isEmpty == false)
      #expect(error.underlyingError == nil)
      #expect(error.rawContent == "12")
    }

    @Test
    func hiddenKeysAreMissingForValueForProperty() throws {
      let content = GeneratedContent(
        kind: .structure(
          properties: ["a": GeneratedContent("1"), "z": GeneratedContent("2")],
          orderedKeys: ["z"]
        )
      )

      let hidden = try content.value(String?.self, forProperty: "a")
      let visible = try content.value(String.self, forProperty: "z")

      #expect(hidden == nil)
      #expect(visible == "2")
      #expect(throws: GeneratedContent.ParsingError.self) {
        try content.value(String.self, forProperty: "a")
      }
    }

    @Test
    func standardTypesRoundTrip() throws {
      let content = GeneratedContent(properties: [
        "bool": true, "string": "s", "int": -7, "float": Float(1.25), "double": 2.5,
        "decimal": Decimal(string: "3.75") ?? 0, "array": [1, 2], "optional": Int?.none,
      ])

      #expect(try content.value(Bool.self, forProperty: "bool"))
      #expect(try content.value(String.self, forProperty: "string") == "s")
      #expect(try content.value(Int.self, forProperty: "int") == -7)
      #expect(try content.value(Float.self, forProperty: "float") == 1.25)
      #expect(try content.value(Double.self, forProperty: "double") == 2.5)
      #expect(try content.value(Decimal.self, forProperty: "decimal") == Decimal(string: "3.75"))
      #expect(try content.value([Int].self, forProperty: "array") == [1, 2])
      #expect(try content.value(Int?.self, forProperty: "optional") == nil)
      #expect(try content.value(GeneratedContent.self) == content)
      #expect(
        content.jsonString
          == #"{"bool": true, "string": "s", "int": -7, "float": 1.25, "double": 2.5, "#
          + #""decimal": 3.75, "array": [1, 2], "optional": null}"#
      )
    }

    @Test
    func neverCannotBeCreatedFromContent() {
      #expect(throws: GeneratedContent.ParsingError.self) {
        try Never(GeneratedContent(kind: .null))
      }
    }
  }
#endif  // compiler(>=6.4)
