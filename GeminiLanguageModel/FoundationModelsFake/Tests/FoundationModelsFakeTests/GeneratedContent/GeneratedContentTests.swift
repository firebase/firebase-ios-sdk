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

  /// Covers `GeneratedContent` traps, key order, descriptions, and coding.
  @Suite("GeneratedContent")
  struct GeneratedContentTests {
    /// Content whose `orderedKeys` lists a key that is not in `properties`.
    static func extraOrderedKeyContent() -> GeneratedContent {
      GeneratedContent(
        kind: .structure(properties: ["a": GeneratedContent("1")], orderedKeys: ["a", "ghost"])
      )
    }

    /// Returns JSON text normalized with sorted keys, or the text itself if it isn't JSON.
    ///
    /// - Parameter text: JSON text, possibly a fragment.
    /// - Returns: The normalized text.
    static func normalizedJSON(_ text: String) -> String {
      guard let data = text.data(using: .utf8),
        let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
        let normalized = try? JSONSerialization.data(
          withJSONObject: object,
          options: [.sortedKeys, .fragmentsAllowed]
        )
      else {
        return text
      }
      return String(decoding: normalized, as: UTF8.self)
    }

    // MARK: - Traps

    // Exit tests spawn a child process, which Swift Testing doesn't support on iOS, tvOS, watchOS,
    // or visionOS. (These trap tests were already excluded on Windows.)
    #if os(macOS) || os(Linux) || os(FreeBSD) || os(OpenBSD)
      @Test
      func duplicateKeysInPropertiesLiteralTrap() async {
        await #expect(processExitsWith: .failure) {
          _ = GeneratedContent(properties: ["a": 1, "a": 2])
        }
      }

      @Test
      func extraOrderedKeyJSONStringTraps() async {
        await #expect(processExitsWith: .failure) {
          _ = GeneratedContentTests.extraOrderedKeyContent().jsonString
        }
      }

      @Test
      func nonFiniteNumbersTrapInJSONString() async {
        await #expect(processExitsWith: .failure) {
          _ = GeneratedContent(Double.nan).jsonString
        }
        await #expect(processExitsWith: .failure) {
          _ = GeneratedContent(Double.infinity).jsonString
        }
      }
    #endif

    // MARK: - API behavior

    @Test
    func jsonStringFormatting() {
      let content = GeneratedContent(properties: [
        "list": [1, 2], "nested": GeneratedContent(properties: ["k": "v/w"]), "big": Int.max,
        "small": 1e-7, "negZero": -0.0, "float": Float(0.1),
      ])

      let json = content.jsonString

      #expect(
        json
          == #"{"list": [1, 2], "nested": {"k": "v/w"}, "big": 9.223372036854776e+18, "#
          + #""small": 1e-07, "negZero": -0, "float": 0.10000000149011612}"#
      )
    }

    @Test
    func debugDescriptionIncludesHiddenKeysAndEscapesSlashes() {
      let content = GeneratedContent(
        kind: .structure(
          properties: ["a": GeneratedContent("x/y"), "z": GeneratedContent("2")],
          orderedKeys: ["z"]
        )
      )

      let description = content.debugDescription

      #expect(
        Self.normalizedJSON(description)
          == Self.normalizedJSON(#"{"z":"2","a":"x/y"}"#)
      )
      #expect(description.contains(#""x\/y""#))
      #expect(content.jsonString == #"{"z": "2"}"#)
    }

    @Test
    func kindRoundTripsThroughInitializer() throws {
      let parsed = try GeneratedContent(json: #"{"a": [1, true, null, "s"], "b": {"c": 2.5}}"#)

      let rebuilt = GeneratedContent(kind: parsed.kind)

      #expect(rebuilt.kind == parsed.kind)
      #expect(rebuilt != parsed)
    }

    @Test
    func optionalGeneratedContent() {
      let none: Int? = nil
      let some: Int? = 3

      #expect(none.generatedContent == GeneratedContent(kind: .null))
      #expect(some.generatedContent == GeneratedContent(3))
    }

    @Test
    func asPartiallyGeneratedReturnsSelfForStandardTypes() {
      #expect(5.asPartiallyGenerated() == 5)
      #expect("x".asPartiallyGenerated() == "x")
      #expect([1, 2].asPartiallyGenerated() == [1, 2])
    }

    // MARK: - ParsingError

    // MARK: - GenerationID

    @Test
    func generationIDsAreUniqueUUIDs() throws {
      let id = GenerationID()

      let other = GenerationID()

      #expect(UUID(uuidString: id.value) != nil)
      #expect(id != other)
      #expect(Set([id, id]).count == 1)
    }

    // MARK: - Codable bridge

    @Test
    func codableBridgeEncodesAllPropertiesIncludingHiddenKeys() throws {
      let content = GeneratedContent(
        kind: .structure(
          properties: [
            "b": GeneratedContent(1), "a": GeneratedContent([true]),
            "hidden": GeneratedContent("h"),
          ],
          orderedKeys: ["b", "a"]
        )
      )

      let encoder = JSONEncoder()
      encoder.outputFormatting = .sortedKeys
      let data = try encoder.encode(CodableGeneratedContent(content))

      #expect(String(decoding: data, as: UTF8.self) == #"{"a":[true],"b":1,"hidden":"h"}"#)
    }

    @Test
    func codableBridgeDecodesLikeApple() throws {
      let json = #"{"n": 3, "s": "x", "list": [1, null, false], "o": {"k": 2.5}}"#

      let decoded = try JSONDecoder().decode(CodableGeneratedContent.self, from: Data(json.utf8))
      let parsed = try GeneratedContent(json: json)

      #expect(decoded.content == parsed)
      #expect(decoded.content.id == nil)
      #expect(decoded.content.isComplete)
    }

    @Test
    func codableBridgeDecodesTopLevelNumberAsComplete() throws {
      let decoded = try JSONDecoder().decode(CodableGeneratedContent.self, from: Data("42".utf8))

      #expect(decoded.content == GeneratedContent(42))
      #expect(decoded.content.isComplete)
    }

    @Test
    func codableBridgeRoundTripsInsideContainers() throws {
      struct Envelope: Codable, Equatable {
        var content: CodableGeneratedContent
        var others: [CodableGeneratedContent]
      }
      let envelope = Envelope(
        content: CodableGeneratedContent(GeneratedContent(properties: ["z": "1", "a": [1.5]])),
        others: [CodableGeneratedContent(GeneratedContent(kind: .null))]
      )

      let encoder = JSONEncoder()
      encoder.outputFormatting = .sortedKeys
      let data = try encoder.encode(envelope)
      let decoded = try JSONDecoder().decode(Envelope.self, from: data)

      #expect(
        String(decoding: data, as: UTF8.self) == #"{"content":{"a":[1.5],"z":"1"},"others":[null]}"#
      )
      #expect(decoded.content.content != envelope.content.content)
      #expect(
        Self.normalizedJSON(decoded.content.content.jsonString)
          == Self.normalizedJSON(envelope.content.content.jsonString)
      )
      #expect(decoded.others == envelope.others)
    }

    @Test
    func codableBridgeRejectsNonFiniteNumbers() {
      #expect(throws: EncodingError.self) {
        try JSONEncoder().encode(CodableGeneratedContent(GeneratedContent(Double.nan)))
      }
    }
  }
#endif  // compiler(>=6.4)
