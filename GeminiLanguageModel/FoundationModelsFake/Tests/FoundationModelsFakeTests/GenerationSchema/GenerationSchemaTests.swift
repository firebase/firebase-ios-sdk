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

  /// Unit tests for guides, names, and dynamic schema shapes.
  @Suite("GenerationSchema guides and names")
  struct GenerationSchemaTests {
    /// A string enumeration that other schemas refer to as `DynPet`.
    static let pet = DynamicGenerationSchema(
      name: "DynPet",
      description: "A pet kind",
      anyOf: ["cat", "dog"]
    )

    /// Returns the compact, key-sorted JSON of a dynamic schema used as the root.
    ///
    /// - Parameter root: The root schema.
    /// - Returns: The JSON text.
    func json(_ root: DynamicGenerationSchema) throws -> String {
      try SchemaJSON.compactSortedJSON(GenerationSchema(root: root, dependencies: []))
    }

    @Test
    func constantGuideReplacesTypeWithConst() throws {
      let root = DynamicGenerationSchema(type: String.self, guides: [.constant("fixed")])

      let schema = try GenerationSchema(root: root, dependencies: [])

      #expect(try SchemaJSON.compactSortedJSON(schema) == #"{"const":"fixed"}"#)
      #expect(schema.name == "fixed")
    }

    @Test
    func anyOfGuideProducesEnum() throws {
      let root = DynamicGenerationSchema(type: String.self, guides: [.anyOf(["a", "b"])])

      let encoded = try json(root)

      #expect(encoded == #"{"enum":["a","b"],"type":"string"}"#)
    }

    @Test
    func patternGuideRegeneratesRegexSource() throws {
      let root = DynamicGenerationSchema(
        type: String.self,
        guides: [.pattern(/\d{3}-\d{4}/)]
      )

      let encoded = try json(root)

      #expect(encoded == #"{"pattern":"\\d{3}\\-\\d{4}","type":"string"}"#)
    }

    @Test
    func patternAndChoicesCombine() throws {
      let root = DynamicGenerationSchema(
        type: String.self,
        guides: [.pattern(/[a-z]+/), .anyOf(["ab"])]
      )

      let encoded = try json(root)

      #expect(encoded == #"{"enum":["ab"],"pattern":"[a-z]+","type":"string"}"#)
    }

    @Test
    func integerGuidesMerge() throws {
      let minimum = DynamicGenerationSchema(type: Int.self, guides: [.minimum(-2)])
      let maximum = DynamicGenerationSchema(type: Int.self, guides: [.maximum(7)])
      let both = DynamicGenerationSchema(type: Int.self, guides: [.minimum(1), .maximum(2)])
      let range = DynamicGenerationSchema(type: Int.self, guides: [.range(3...4), .maximum(9)])

      let encoded = try [minimum, maximum, both, range].map(json)

      #expect(
        encoded == [
          #"{"minimum":-2,"type":"integer"}"#, #"{"maximum":7,"type":"integer"}"#,
          #"{"maximum":2,"minimum":1,"type":"integer"}"#,
          #"{"maximum":9,"minimum":3,"type":"integer"}"#,
        ]
      )
    }

    @Test
    func floatingPointGuidesPrintAsJSONNumbers() throws {
      let double = DynamicGenerationSchema(type: Double.self, guides: [.range(0.5...1.0)])
      let float = DynamicGenerationSchema(type: Float.self, guides: [.range(0.25...4)])
      let decimal = DynamicGenerationSchema(
        type: Decimal.self,
        guides: [.minimum(Decimal(string: "0.75") ?? 0), .maximum(99)]
      )

      let encoded = try [double, float, decimal].map(json)

      #expect(
        encoded == [
          #"{"maximum":1,"minimum":0.5,"type":"number"}"#,
          #"{"maximum":4,"minimum":0.25,"type":"number"}"#,
          #"{"maximum":99,"minimum":0.75,"type":"number"}"#,
        ]
      )
    }

    @Test
    func countGuidesSetItemBounds() throws {
      let exact = DynamicGenerationSchema(type: [Int].self, guides: [.count(2)])
      let range = DynamicGenerationSchema(type: [Int].self, guides: [.count(1...3)])
      let minimum = DynamicGenerationSchema(type: [Int].self, guides: [.minimumCount(1)])
      let maximum = DynamicGenerationSchema(type: [Int].self, guides: [.maximumCount(5)])

      let encoded = try [exact, range, minimum, maximum].map(json)

      #expect(
        encoded == [
          #"{"items":{"type":"integer"},"maxItems":2,"minItems":2,"type":"array"}"#,
          #"{"items":{"type":"integer"},"maxItems":3,"minItems":1,"type":"array"}"#,
          #"{"items":{"type":"integer"},"minItems":1,"type":"array"}"#,
          #"{"items":{"type":"integer"},"maxItems":5,"type":"array"}"#,
        ]
      )
    }

    @Test
    func elementGuidesApplyToNestedArrays() throws {
      let root = DynamicGenerationSchema(
        type: [[Int]].self,
        guides: [.element(.element(.minimum(0))), .element(.count(2))]
      )

      let encoded = try json(root)

      #expect(
        encoded
          == #"{"items":{"items":{"minimum":0,"type":"integer"},"maxItems":2,"minItems":2,"#
          + #""type":"array"},"type":"array"}"#
      )
    }

    @Test
    func standardTypeNames() {
      let names = [
        String.generationSchema.name, Int.generationSchema.name, Double.generationSchema.name,
        Float.generationSchema.name, Decimal.generationSchema.name, Bool.generationSchema.name,
        [Bool].generationSchema.name, [[SchemaTestTypes.Address]].generationSchema.name,
        GeneratedContent.generationSchema.name, DynamicGenerationSchemaName.null,
      ]

      let expected = [
        "String", "Int", "Double", "Double", "Double", "Bool", "Array<Bool>",
        "Array<Array<Address>>", "GeneratedContent", "Null",
      ]

      #expect(names == expected)
    }

    @Test
    func dynamicReferenceToGenerableDependencyIsHoisted() throws {
      let root = DynamicGenerationSchema(
        name: "Owner",
        properties: [.init(name: "home", schema: DynamicGenerationSchema(referenceTo: "Address"))]
      )

      let schema = try GenerationSchema(
        root: root,
        dependencies: [DynamicGenerationSchema(type: SchemaTestTypes.Address.self)]
      )

      let encoded = try SchemaJSON.compactSortedJSON(schema)
      #expect(encoded.hasPrefix(#"{"$defs":{"Address":{"additionalProperties":false,"#))
      #expect(encoded.contains(##""home":{"$ref":"#/$defs/Address"}"##))
    }

    @Test
    func referencedEnumerationIsInlined() throws {
      let root = DynamicGenerationSchema(
        name: "Owner",
        properties: [.init(name: "pet", schema: DynamicGenerationSchema(referenceTo: "DynPet"))]
      )

      let schema = try GenerationSchema(root: root, dependencies: [Self.pet])

      let encoded = try SchemaJSON.compactSortedJSON(schema)
      #expect(!encoded.contains("$defs"))
      #expect(encoded.contains(#""pet":{"enum":["cat","dog"],"type":"string"}"#))
    }

    @Test
    func mutuallyRecursiveDependenciesTerminate() throws {
      let a = DynamicGenerationSchema(
        name: "A",
        properties: [.init(name: "b", schema: DynamicGenerationSchema(referenceTo: "B"))]
      )
      let b = DynamicGenerationSchema(
        name: "B",
        properties: [
          .init(name: "a", schema: DynamicGenerationSchema(referenceTo: "A"), isOptional: true)
        ]
      )

      let schema = try GenerationSchema(root: a, dependencies: [b])

      let encoded = try SchemaJSON.compactSortedJSON(schema)
      #expect(encoded.contains(##""a":{"$ref":"#"}"##))
      #expect(encoded.contains(##""b":{"$ref":"#/$defs/B"}"##))
    }

    @Test(arguments: [
      ##"{"$ref":"#"}"##,
      ##"{"$ref":"#/$defs/A","$defs":{"A":{"$ref":"#/$defs/A"}}}"##,
      ##"{"$ref":"#/$defs/A","$defs":{"A":{"$ref":"#/$defs/B"},"B":{"$ref":"#/$defs/A"}}}"##,
      ##"{"$ref":"#/$defs/A","$defs":{"A":{"$ref":"#"}}}"##,
    ])
    func referenceOnlyCyclesFailToDecode(json: String) {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(GenerationSchema.self, from: Data(json.utf8))
      }
    }

    @Test
    func referenceCycleErrorNamesOnlyTheCycle() throws {
      let json =
        ##"{"$ref":"#/$defs/A","$defs":{"A":{"$ref":"#/$defs/B"},"B":{"$ref":"#/$defs/B"}}}"##

      let error = try #require(throws: DecodingError.self) {
        try JSONDecoder().decode(GenerationSchema.self, from: Data(json.utf8))
      }

      guard case .dataCorrupted(let context) = error else {
        Issue.record("Expected dataCorrupted, got \(error).")
        return
      }
      #expect(context.debugDescription == "References that only refer to each other: [B]")
    }

    @Test(arguments: [
      ##"{"type":"object","properties":{"s":{"$ref":"#"}},"required":[],"##
        + ##""additionalProperties":false,"x-order":["s"]}"##,
      ##"{"type":"array","items":{"$ref":"#"}}"##,
    ])
    func untitledRootReferencedByHashFailsToDecode(json: String) {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(GenerationSchema.self, from: Data(json.utf8))
      }
    }

    @Test
    func untitledRecursiveDefinitionIsNamedByItsKey() throws {
      let json = ##"""
        {"$defs":{"Node":{"additionalProperties":false,"properties":{"next":{"$ref":"#/$defs/Node"}},\##
        "required":[],"type":"object","x-order":["next"]}},"additionalProperties":false,\##
        "properties":{"node":{"$ref":"#/$defs/Node"}},"required":["node"],"title":"Root",\##
        "type":"object","x-order":["node"]}
        """##
      let schema = try JSONDecoder().decode(GenerationSchema.self, from: Data(json.utf8))

      let encoded = try SchemaJSON.compactSortedJSON(schema)

      #expect(encoded.contains(#""title":"Node""#))
      #expect(encoded.contains(##""next":{"$ref":"#/$defs/Node"}"##))
    }

    @Test
    func generatedContentPropertyIsHoistedWithSelfReferences() throws {
      let schema = GenerationSchema(
        type: SchemaTestTypes.Address.self,
        properties: [GenerationSchema.Property(name: "extra", type: GeneratedContent.self)]
      )

      let encoded = try SchemaJSON.compactSortedJSON(schema)

      #expect(encoded.contains(##""extra":{"$ref":"#/$defs/GeneratedContent"}"##))
      #expect(encoded.contains(##""items":{"$ref":"#/$defs/GeneratedContent"}"##))
    }
  }

  /// Names that need a schema built first.
  private enum DynamicGenerationSchemaName {
    /// The name of `GenerationSchema(root: .null, dependencies: [])`.
    static var null: String {
      (try? GenerationSchema(root: .null, dependencies: []))?.name ?? ""
    }
  }
#endif  // compiler(>=6.4)
