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

  /// Types whose short names collide.
  enum CollisionTypes {
    /// The first type named `Item`.
    enum A {
      /// `A.Item { var a: Int }`.
      struct Item: SchemaOnlyGenerable {
        /// The macro-equivalent schema.
        static var generationSchema: GenerationSchema {
          GenerationSchema(type: Self.self, properties: [.init(name: "a", type: Int.self)])
        }
      }
    }

    /// The second type named `Item`.
    enum B {
      /// `B.Item { var b: String }`.
      struct Item: SchemaOnlyGenerable {
        /// The macro-equivalent schema.
        static var generationSchema: GenerationSchema {
          GenerationSchema(type: Self.self, properties: [.init(name: "b", type: String.self)])
        }
      }
    }

    /// A nested type named like the root type `Parent2`.
    enum C {
      /// `C.Parent2 { var x: Int }`.
      struct Parent2: SchemaOnlyGenerable {
        /// The macro-equivalent schema.
        static var generationSchema: GenerationSchema {
          GenerationSchema(type: Self.self, properties: [.init(name: "x", type: Int.self)])
        }
      }
    }

    /// Refers to both `Item` types.
    struct Parent: SchemaOnlyGenerable {
      /// The macro-equivalent schema.
      static var generationSchema: GenerationSchema {
        GenerationSchema(
          type: Self.self,
          properties: [
            .init(name: "first", type: A.Item.self), .init(name: "second", type: B.Item.self),
          ]
        )
      }
    }

    /// Refers to arrays of both `Item` types.
    struct ParentArrays: SchemaOnlyGenerable {
      /// The macro-equivalent schema.
      static var generationSchema: GenerationSchema {
        GenerationSchema(
          type: Self.self,
          properties: [
            .init(name: "firsts", type: [A.Item].self),
            .init(name: "seconds", type: [B.Item].self),
          ]
        )
      }
    }

    /// Has a property whose type is named like itself.
    struct Parent2: SchemaOnlyGenerable {
      /// The macro-equivalent schema.
      static var generationSchema: GenerationSchema {
        GenerationSchema(type: Self.self, properties: [.init(name: "child", type: C.Parent2.self)])
      }
    }

    /// A union of both `Item` types.
    struct Union: SchemaOnlyGenerable {
      /// The macro-equivalent schema.
      static var generationSchema: GenerationSchema {
        GenerationSchema(type: Self.self, anyOf: [A.Item.self, B.Item.self])
      }
    }
  }

  /// A schema construction with colliding type names and its expected encoding.
  struct NameCollisionCase: Sendable, CustomTestStringConvertible {
    /// A label for the case.
    let label: String

    /// Builds the schema.
    let build: @Sendable () throws -> GenerationSchema

    /// The expected compact, key-sorted JSON (without escaped slashes), or `nil` if building throws.
    let json: String?

    /// The expected `errorDescription` when building throws.
    let error: String?

    /// The label, shown in test results.
    var testDescription: String { label }
  }

  /// Checks that types with the same short name behave as in Apple's framework: they share the
  /// first `$defs` entry, a nested type named like the root becomes `#`, and a dependency whose
  /// name appears anywhere in the root's tree is a duplicate type.
  @Suite("GenerationSchema name collisions")
  struct SchemaNameCollisionTests {
    /// `A.Item`'s definition.
    static let itemA =
      #"{"additionalProperties":false,"properties":{"a":{"type":"integer"}},"required":["a"],"#
      + #""title":"Item","type":"object","x-order":["a"]}"#

    /// An inline dynamic `Item` with one integer property `z`.
    static let itemZ =
      #"{"additionalProperties":false,"properties":{"z":{"type":"integer"}},"required":["z"],"#
      + #""title":"Item","type":"object","x-order":["z"]}"#

    /// Returns an object named `name` with one integer property.
    ///
    /// - Parameters:
    ///   - name: The object's name.
    ///   - property: The property's name.
    /// - Returns: The dynamic schema.
    static func object(_ name: String, _ property: String) -> DynamicGenerationSchema {
      DynamicGenerationSchema(
        name: name,
        properties: [.init(name: property, schema: DynamicGenerationSchema(type: Int.self))]
      )
    }

    /// Returns an object named `R` with the given properties.
    ///
    /// - Parameter properties: The properties as name–schema pairs.
    /// - Returns: The dynamic schema.
    static func root(_ properties: [(String, DynamicGenerationSchema)]) -> DynamicGenerationSchema {
      DynamicGenerationSchema(
        name: "R",
        properties: properties.map { .init(name: $0.0, schema: $0.1) }
      )
    }

    /// The expected error description for a duplicate `Item` in the schema named `schema`.
    static func duplicateItem(in schema: String = "R") -> String? {
      GenerationSchema.SchemaError.duplicateType(
        schema: schema,
        type: "Item",
        context: GenerationSchema.SchemaError.Context(debugDescription: "")
      ).errorDescription
    }

    /// Every recorded case.
    static let cases: [NameCollisionCase] = {
      typealias D = DynamicGenerationSchema
      typealias T = CollisionTypes
      let itemA = Self.itemA
      let itemZ = Self.itemZ
      return [
        NameCollisionCase(
          label: "Parent",
          build: { T.Parent.generationSchema },
          json: ##"{"$defs":{"Item":"## + itemA + ##"},"additionalProperties":false,"##
            + ##""properties":{"first":{"$ref":"#/$defs/Item"},"second":{"$ref":"#/$defs/Item"}},"##
            + ##""required":["first","second"],"title":"Parent","type":"object","##
            + ##""x-order":["first","second"]}"##,
          error: nil
        ),
        NameCollisionCase(
          label: "ParentArrays",
          build: { T.ParentArrays.generationSchema },
          json: ##"{"$defs":{"Item":"## + itemA + ##"},"additionalProperties":false,"##
            + ##""properties":{"firsts":{"items":{"$ref":"#/$defs/Item"},"type":"array"},"##
            + ##""seconds":{"items":{"$ref":"#/$defs/Item"},"type":"array"}},"##
            + ##""required":["firsts","seconds"],"title":"ParentArrays","type":"object","##
            + ##""x-order":["firsts","seconds"]}"##,
          error: nil
        ),
        NameCollisionCase(
          label: "nested type named like the root",
          build: { T.Parent2.generationSchema },
          json: ##"{"additionalProperties":false,"properties":{"child":{"$ref":"#"}},"##
            + ##""required":["child"],"title":"Parent2","type":"object","x-order":["child"]}"##,
          error: nil
        ),
        NameCollisionCase(
          label: "Union",
          build: { T.Union.generationSchema },
          json: ##"{"$defs":{"Item":"## + itemA + ##"},"##
            + ##""anyOf":[{"$ref":"#/$defs/Item"},{"$ref":"#/$defs/Item"}],"title":"Union"}"##,
          error: nil
        ),
        NameCollisionCase(
          label: "dynamic types in root",
          build: {
            try GenerationSchema(
              root: root([("x", D(type: T.A.Item.self)), ("y", D(type: T.B.Item.self))]),
              dependencies: []
            )
          },
          json: ##"{"$defs":{"Item":"## + itemA + ##"},"additionalProperties":false,"##
            + ##""properties":{"x":{"$ref":"#/$defs/Item"},"y":{"$ref":"#/$defs/Item"}},"##
            + ##""required":["x","y"],"title":"R","type":"object","x-order":["x","y"]}"##,
          error: nil
        ),
        NameCollisionCase(
          label: "type in root, dependency type",
          build: {
            try GenerationSchema(
              root: root([("x", D(type: T.A.Item.self))]),
              dependencies: [D(type: T.B.Item.self)]
            )
          },
          json: nil,
          error: duplicateItem()
        ),
        NameCollisionCase(
          label: "a: type in root, dependency object",
          build: {
            try GenerationSchema(
              root: root([("x", D(type: T.A.Item.self))]),
              dependencies: [object("Item", "z")]
            )
          },
          json: nil,
          error: duplicateItem()
        ),
        NameCollisionCase(
          label: "b: inline object in root, dependency type",
          build: {
            try GenerationSchema(
              root: root([("x", object("Item", "z"))]),
              dependencies: [D(type: T.B.Item.self)]
            )
          },
          json: nil,
          error: duplicateItem()
        ),
        NameCollisionCase(
          label: "c: type with nested Item in root, dependency object",
          build: {
            try GenerationSchema(
              root: root([("x", D(type: T.Parent.self))]),
              dependencies: [object("Item", "z")]
            )
          },
          json: nil,
          error: duplicateItem()
        ),
        NameCollisionCase(
          label: "d: inline object then type in root",
          build: {
            try GenerationSchema(
              root: root([("x", object("Item", "z")), ("y", D(type: T.A.Item.self))]),
              dependencies: []
            )
          },
          json: ##"{"$defs":{"Item":"## + itemZ + ##"},"additionalProperties":false,"##
            + ##""properties":{"x":{"$ref":"#/$defs/Item"},"y":{"$ref":"#/$defs/Item"}},"##
            + ##""required":["x","y"],"title":"R","type":"object","x-order":["x","y"]}"##,
          error: nil
        ),
        NameCollisionCase(
          label: "d2: type then inline object in root",
          build: {
            try GenerationSchema(
              root: root([("y", D(type: T.A.Item.self)), ("x", object("Item", "z"))]),
              dependencies: []
            )
          },
          json: ##"{"$defs":{"Item":"## + itemA + ##"},"additionalProperties":false,"##
            + ##""properties":{"x":{"$ref":"#/$defs/Item"},"y":{"$ref":"#/$defs/Item"}},"##
            + ##""required":["y","x"],"title":"R","type":"object","x-order":["y","x"]}"##,
          error: nil
        ),
        NameCollisionCase(
          label: "d3: two different inline objects in root",
          build: {
            try GenerationSchema(
              root: root([("x", object("Item", "z")), ("y", object("Item", "w"))]),
              dependencies: []
            )
          },
          json: ##"{"$defs":{"Item":"## + itemZ + ##"},"additionalProperties":false,"##
            + ##""properties":{"x":{"$ref":"#/$defs/Item"},"y":{"$ref":"#/$defs/Item"}},"##
            + ##""required":["x","y"],"title":"R","type":"object","x-order":["x","y"]}"##,
          error: nil
        ),
        NameCollisionCase(
          label: "e: dependency contains a type, another dependency has its name",
          build: {
            try GenerationSchema(
              root: root([("x", D(referenceTo: "D1"))]),
              dependencies: [
                D(name: "D1", properties: [.init(name: "i", schema: D(type: T.A.Item.self))]),
                D(type: T.B.Item.self),
              ]
            )
          },
          json: ##"{"$defs":{"D1":{"additionalProperties":false,"##
            + ##""properties":{"i":{"$ref":"#/$defs/Item"}},"required":["i"],"title":"D1","##
            + ##""type":"object","x-order":["i"]},"Item":"## + itemA + ##"},"##
            + ##""additionalProperties":false,"properties":{"x":{"$ref":"#/$defs/D1"}},"##
            + ##""required":["x"],"title":"R","type":"object","x-order":["x"]}"##,
          error: nil
        ),
        NameCollisionCase(
          label: "f: reference resolved by a type nested in the root",
          build: {
            try GenerationSchema(
              root: root([("x", D(type: T.A.Item.self)), ("y", D(referenceTo: "Item"))]),
              dependencies: []
            )
          },
          json: ##"{"$defs":{"Item":"## + itemA + ##"},"additionalProperties":false,"##
            + ##""properties":{"x":{"$ref":"#/$defs/Item"},"y":{"$ref":"#/$defs/Item"}},"##
            + ##""required":["x","y"],"title":"R","type":"object","x-order":["x","y"]}"##,
          error: nil
        ),
        NameCollisionCase(
          label: "g: root type with nested Item, dependency type",
          build: {
            try GenerationSchema(
              root: D(type: T.Parent.self),
              dependencies: [D(type: T.B.Item.self)]
            )
          },
          json: nil,
          error: duplicateItem(in: "Parent")
        ),
        NameCollisionCase(
          label: "h: inline object in a dependency, another dependency has its name",
          build: {
            try GenerationSchema(
              root: root([("x", D(referenceTo: "D1"))]),
              dependencies: [
                D(name: "D1", properties: [.init(name: "i", schema: object("Item", "z"))]),
                object("Item", "q"),
              ]
            )
          },
          json: ##"{"$defs":{"D1":{"additionalProperties":false,"##
            + ##""properties":{"i":{"$ref":"#/$defs/Item"}},"required":["i"],"title":"D1","##
            + ##""type":"object","x-order":["i"]},"Item":"## + itemZ + ##"},"##
            + ##""additionalProperties":false,"properties":{"x":{"$ref":"#/$defs/D1"}},"##
            + ##""required":["x"],"title":"R","type":"object","x-order":["x"]}"##,
          error: nil
        ),
        NameCollisionCase(
          label: "i: the same type as two dependencies",
          build: {
            try GenerationSchema(
              root: root([("x", D(referenceTo: "Item"))]),
              dependencies: [D(type: T.A.Item.self), D(type: T.A.Item.self)]
            )
          },
          json: nil,
          error: duplicateItem()
        ),
        NameCollisionCase(
          label: "j: one inline object used twice, dependency object",
          build: {
            let item = object("Item", "z")
            return try GenerationSchema(
              root: root([("x", item), ("y", D(arrayOf: item))]),
              dependencies: [object("Item", "q")]
            )
          },
          json: nil,
          error: duplicateItem()
        ),
        NameCollisionCase(
          label: "k: inline enumeration in root, dependency object",
          build: {
            try GenerationSchema(
              root: root([("x", D(name: "Item", anyOf: ["a"]))]),
              dependencies: [object("Item", "q")]
            )
          },
          json: nil,
          error: duplicateItem()
        ),
      ]
    }()

    @Test(arguments: cases)
    func collisionMatchesApple(_ testCase: NameCollisionCase) throws {
      let result = Result { try testCase.build() }

      switch result {
      case .success(let schema):
        #expect(testCase.error == nil, "Expected error: \(testCase.error ?? "")")
        #expect(try SchemaJSON.compactSortedJSON(schema) == testCase.json)
      case .failure(let error):
        let schemaError = try #require(error as? GenerationSchema.SchemaError)
        #expect(schemaError.errorDescription == testCase.error)
      }
    }

    @Test
    func duplicateTypeContextNamesTheRoot() throws {
      let error = try #require(throws: GenerationSchema.SchemaError.self) {
        try GenerationSchema(
          root: DynamicGenerationSchema(type: CollisionTypes.Parent.self),
          dependencies: [DynamicGenerationSchema(type: CollisionTypes.B.Item.self)]
        )
      }

      guard case .duplicateType(let schema, let type, let context) = error else {
        Issue.record("Expected duplicateType, got \(error)")
        return
      }
      #expect(schema == "Parent")
      #expect(type == "Item")
      #expect(context.debugDescription.contains("Item"))
      #expect(context.debugDescription.contains("Parent"))
    }
  }
#endif  // compiler(>=6.4)
