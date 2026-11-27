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
  import FoundationModelsFake
  import Testing

  /// Checks the generated `generatedContent`, `init(_:)`, and `PartiallyGenerated` members at run
  /// time. Expected values match Apple's framework for the same declarations.
  @Suite
  struct GenerableMacroContentTests {
    /// A sample address.
    static let address = MacroFixtures.Address(street: "1 Main", city: "Springfield")

    /// A sample person with some optionals unset.
    static let person = MacroFixtures.Person(
      name: "Ada",
      nickname: nil,
      age: 36,
      tags: ["a", "b"],
      scores: nil,
      address: address,
      previousAddresses: [address],
      optionalAddress: nil
    )

    /// Every case of `Shape`, with the JSON Apple's framework generates for it.
    static let shapes: [(shape: MacroFixtures.Shape, json: String)] = [
      (.empty, #"{"type": "empty"}"#),
      (.circle(1.5), #"{"type": "circle", "value": 1.5}"#),
      (.square(side: 2), #"{"type": "square", "side": 2}"#),
      (.rectangle(width: 1, height: 2), #"{"type": "rectangle", "width": 1, "height": 2}"#),
      (.labeled("x", count: 3), #"{"type": "labeled", "value": "x", "count": 3}"#),
      (
        .located(address),
        #"{"type": "located", "value": {"street": "1 Main", "city": "Springfield"}}"#
      ),
    ]

    /// The indices of `shapes`, used as test arguments.
    static let shapeIndices = Array(shapes.indices)

    // MARK: - generatedContent

    /// Optional properties that are `nil` are omitted.
    @Test
    func structContentOmitsNilOptionals() {
      let json = Self.person.generatedContent.jsonString

      #expect(
        json
          == #"{"name": "Ada", "age": 36, "tags": ["a", "b"], "address": {"street": "1 Main", "#
          + #""city": "Springfield"}, "previousAddresses": [{"street": "1 Main", "city": "#
          + #""Springfield"}]}"#
      )
    }

    /// `representNilExplicitlyInGeneratedContent` writes `nil` optionals as `null`.
    @Test
    func explicitNilContentIncludesNull() {
      let value = MacroFixtures.ExplicitNil(present: 1, missing: nil, missingArray: nil)

      let json = value.generatedContent.jsonString

      #expect(json == #"{"present": 1, "missing": null, "missingArray": null}"#)
    }

    /// Every primitive type is converted.
    @Test
    func primitivesContent() {
      let value = MacroFixtures.Primitives(
        string: "s", int: 1, double: 2.5, float: 1.5, bool: true, decimal: 3.25)

      let json = value.generatedContent.jsonString

      #expect(
        json == #"{"string": "s", "int": 1, "double": 2.5, "float": 1.5, "bool": true, "#
          + #""decimal": 3.25}"#
      )
    }

    /// Simple and Int-raw-value enums use case names; String-raw-value enums use raw values.
    @Test
    func enumContent() {
      #expect(MacroFixtures.SimpleColor.green.generatedContent.jsonString == #""green""#)
      #expect(MacroFixtures.Priority.high.generatedContent.jsonString == #""high""#)
      #expect(MacroFixtures.ShirtSize.small.generatedContent.jsonString == #""S""#)
      #expect(MacroFixtures.ShirtSize.large.generatedContent.jsonString == #""large""#)
    }

    /// Enums with associated values become objects with a `type` discriminator.
    @Test(arguments: shapeIndices)
    func associatedValueEnumContent(index: Int) throws {
      let (shape, expected) = Self.shapes[index]

      let json = shape.generatedContent.jsonString

      #expect(json == expected)
    }

    /// Nested structs, enums, and arrays of enums are converted.
    @Test
    func nestedContent() {
      let wardrobe = MacroFixtures.Wardrobe(
        color: .red, size: .medium, shape: .circle(2), colors: [.blue, .green])

      let json = wardrobe.generatedContent.jsonString

      #expect(
        json == #"{"color": "red", "size": "M", "shape": {"type": "circle", "value": 2}, "#
          + #""colors": ["blue", "green"]}"#
      )
    }

    /// Defaulted, recursive, and optional-with-guide properties are converted.
    @Test
    func otherStructContent() {
      let lets = MacroFixtures.LetsAndDefaults(identifier: "x")
      let tree = MacroFixtures.TreeNode(
        value: 1, children: [MacroFixtures.TreeNode(value: 2, children: [])])
      let weather = MacroFixtures.WeatherArguments(city: "Paris", units: nil)

      #expect(lets.generatedContent.jsonString == #"{"identifier": "x", "count": 5}"#)
      #expect(
        tree.generatedContent.jsonString
          == #"{"value": 1, "children": [{"value": 2, "children": []}]}"#
      )
      #expect(weather.generatedContent.jsonString == #"{"city": "Paris"}"#)
    }

    // MARK: - init(_:)

    /// A struct survives a round trip through generated content.
    @Test
    func structRoundTrip() throws {
      let content = Self.person.generatedContent

      let decoded = try MacroFixtures.Person(content)

      #expect(decoded == Self.person)
    }

    /// Every case of an enum with associated values survives a round trip.
    @Test(arguments: shapeIndices)
    func associatedValueEnumRoundTrip(index: Int) throws {
      let shape = Self.shapes[index].shape

      let decoded = try MacroFixtures.Shape(shape.generatedContent)

      #expect(decoded == shape)
    }

    /// A struct containing enums survives a round trip.
    @Test
    func nestedRoundTrip() throws {
      let wardrobe = MacroFixtures.Wardrobe(
        color: .red, size: .medium, shape: .labeled("x", count: 3), colors: [.blue])

      let decoded = try MacroFixtures.Wardrobe(wardrobe.generatedContent)

      #expect(decoded == wardrobe)
    }

    /// Enums decode from case names or raw values, as generated.
    @Test
    func enumDecoding() throws {
      #expect(try MacroFixtures.Priority(GeneratedContent(json: #""high""#)) == .high)
      #expect(try MacroFixtures.ShirtSize(GeneratedContent(json: #""S""#)) == .small)
      #expect(try MacroFixtures.SimpleColor(GeneratedContent(json: #""blue""#)) == .blue)
    }

    /// Unknown enum values throw `ParsingError` with Apple's messages.
    @Test
    func unexpectedEnumValuesThrow() throws {
      let color = try GeneratedContent(json: #""purple""#)
      let size = try GeneratedContent(json: #""small""#)
      let shape = try GeneratedContent(json: #"{"type": "hexagon"}"#)

      let colorError = #expect(throws: GeneratedContent.ParsingError.self) {
        try MacroFixtures.SimpleColor(color)
      }
      let sizeError = #expect(throws: GeneratedContent.ParsingError.self) {
        try MacroFixtures.ShirtSize(size)
      }
      let shapeError = #expect(throws: GeneratedContent.ParsingError.self) {
        try MacroFixtures.Shape(shape)
      }

      #expect(colorError?.debugDescription == #""purple" isn't a case of SimpleColor"#)
      #expect(colorError?.rawContent == #""purple""#)
      #expect(sizeError?.debugDescription == #""small" isn't a raw value of ShirtSize"#)
      #expect(shapeError?.debugDescription == #"The type "hexagon" isn't a case of Shape"#)
    }

    /// Missing required properties throw.
    @Test
    func missingRequiredPropertyThrows() throws {
      let content = try GeneratedContent(json: #"{"name": "x"}"#)

      #expect(throws: GeneratedContent.ParsingError.self) {
        try MacroFixtures.Person(content)
      }
    }

    // MARK: - PartiallyGenerated

    /// Partial JSON fills in the properties generated so far.
    @Test
    func partiallyGeneratedFromPartialJSON() throws {
      let first = try GeneratedContent(json: #"{"name": "Al"#)
      let second = try GeneratedContent(json: #"{"name": "Alan", "nickname": null, "age": 4"#)
      let third = try GeneratedContent(json: #"{"name": "Alan", "tags": ["x", "y"#)
      let fourth = try GeneratedContent(json: #"{"name": "Alan", "address": {"street": "Ma"#)

      let firstPartial = try MacroFixtures.Person.PartiallyGenerated(first)
      let secondPartial = try MacroFixtures.Person.PartiallyGenerated(second)
      let thirdPartial = try MacroFixtures.Person.PartiallyGenerated(third)
      let fourthPartial = try MacroFixtures.Person.PartiallyGenerated(fourth)

      #expect(firstPartial.name == "Al")
      #expect(firstPartial.age == nil)
      #expect(secondPartial.name == "Alan")
      #expect(secondPartial.nickname == nil)
      #expect(secondPartial.age == 4)
      #expect(thirdPartial.tags == ["x", "y"])
      #expect(fourthPartial.address?.street == "Ma")
      #expect(fourthPartial.address?.city == nil)
      #expect(fourthPartial.previousAddresses == nil)
    }

    /// An empty object produces a `PartiallyGenerated` value with every property `nil`.
    @Test
    func partiallyGeneratedFromEmptyObject() throws {
      let content = try GeneratedContent(json: "{")

      let partial = try MacroFixtures.Person.PartiallyGenerated(content)

      #expect(partial.name == nil)
      #expect(partial.tags == nil)
      #expect(partial.address == nil)
    }

    /// `PartiallyGenerated` takes the content's generation ID.
    @Test
    func partiallyGeneratedUsesContentID() throws {
      let id = GenerationID()
      let content = GeneratedContent(properties: ["street": "Main"], id: id)

      let partial = try MacroFixtures.Address.PartiallyGenerated(content)

      #expect(partial.id == id)
      #expect(partial.street == "Main")
    }

    /// The partial form of an enum with associated values decodes the case and its partial
    /// payload.
    @Test
    func partiallyGeneratedEnum() throws {
      let content = try GeneratedContent(json: #"{"type": "rectangle", "width": 2"#)

      let partial = try MacroFixtures.Shape.PartiallyGenerated(content)

      #expect(partial == .rectangle(width: 2, height: nil))
    }

    /// A partial discriminator throws, as in Apple's framework.
    @Test
    func partiallyGeneratedEnumWithPartialTypeThrows() throws {
      let content = try GeneratedContent(json: #"{"type": "circ"#)

      let error = #expect(throws: GeneratedContent.ParsingError.self) {
        try MacroFixtures.Shape.PartiallyGenerated(content)
      }

      #expect(error?.debugDescription == #"The type "circ" isn't a case of PartiallyGenerated"#)
    }

    /// `asPartiallyGenerated()` converts through generated content.
    @Test
    func asPartiallyGenerated() {
      let partial = Self.person.asPartiallyGenerated()

      #expect(partial.name == "Ada")
      #expect(partial.address?.city == "Springfield")
    }

    // MARK: - Edge cases

    /// An `id: GenerationID` property maps to the content's ID.
    @Test
    func generationIDPropertyRoundTrip() throws {
      let term = MacroEdgeCases.SearchTerm(id: GenerationID(), searchTerm: "Beautiful sunsets")

      let content = term.generatedContent
      let decoded = try MacroEdgeCases.SearchTerm(content)
      let partial = try MacroEdgeCases.SearchTerm.PartiallyGenerated(content)

      #expect(content.id == term.id)
      #expect(content.jsonString == #"{"searchTerm": "Beautiful sunsets"}"#)
      #expect(decoded == term)
      #expect(partial.id == term.id)
    }

    /// An `id` property that isn't a `GenerationID` is a regular property.
    @Test
    func nonGenerationIDPropertyIsRegular() throws {
      let tagged = MacroEdgeCases.Tagged(id: "a", value: 1)

      let partial = try MacroEdgeCases.Tagged.PartiallyGenerated(tagged.generatedContent)
      let other = try MacroEdgeCases.Tagged.PartiallyGenerated(tagged.generatedContent)

      #expect(partial.id == "a")
      #expect(partial == other)
    }

    /// Unlabeled associated values are named `value`, `value1`, ...
    @Test
    func unlabeledAssociatedValues() throws {
      let payload = MacroEdgeCases.Payload.pair(1, 2)

      let json = payload.generatedContent.jsonString
      let decoded = try MacroEdgeCases.Payload(payload.generatedContent)

      #expect(json == #"{"type": "pair", "value": 1, "value1": 2}"#)
      #expect(decoded == payload)
    }

    /// Backticked, multiple-binding, and observed properties round-trip.
    @Test
    func storedPropertyFormsRoundTrip() throws {
      let forms = MacroEdgeCases.Forms(default: 1, first: 2, second: 3, observed: 4)

      let decoded = try MacroEdgeCases.Forms(forms.generatedContent)

      #expect(
        forms.generatedContent.jsonString
          == #"{"default": 1, "first": 2, "second": 3, "observed": 4}"#
      )
      #expect(decoded == forms)
    }

    /// An `id: GenerationID?` property maps to the content's ID, which may be absent.
    @Test
    func optionalGenerationIDProperty() throws {
      let id = GenerationID()
      let draft = MacroEdgeCases.Draft(id: id, text: "Hi")
      let anonymous = try GeneratedContent(json: #"{"text": "Hi"}"#)

      let decoded = try MacroEdgeCases.Draft(draft.generatedContent)
      let decodedAnonymous = try MacroEdgeCases.Draft(anonymous)

      #expect(draft.generatedContent.id == id)
      #expect(decoded == draft)
      #expect(decodedAnonymous.id == nil)
      #expect(decodedAnonymous.text == "Hi")
    }

    /// Associated value labels that are keywords round-trip.
    @Test
    func keywordAssociatedValueLabels() throws {
      let value = MacroEdgeCases.Keyword.range(default: 1, in: "x")

      let json = value.generatedContent.jsonString
      let decoded = try MacroEdgeCases.Keyword(value.generatedContent)

      #expect(json == #"{"type": "range", "default": 1, "in": "x"}"#)
      #expect(decoded == value)
    }

    /// Public types get public generated members and round-trip.
    @Test
    func publicTypesRoundTrip() throws {
      let record = MacroPublicRecord(
        name: "r", shape: .line(length: 3), level: .high, tags: nil)

      let json = record.generatedContent.jsonString
      let decoded = try MacroPublicRecord(record.generatedContent)
      let partial = try MacroPublicRecord.PartiallyGenerated(record.generatedContent)

      #expect(
        json == #"{"name": "r", "shape": {"type": "line", "length": 3}, "level": "high"}"#)
      #expect(decoded == record)
      #expect(partial.shape == .line(length: 3))
      #expect(partial.level == .high)
    }
  }
#endif  // compiler(>=6.4)
