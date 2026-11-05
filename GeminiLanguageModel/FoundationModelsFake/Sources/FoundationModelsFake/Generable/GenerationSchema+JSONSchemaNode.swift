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
  #if canImport(FoundationEssentials)
    import FoundationEssentials
  #else
    import Foundation
  #endif

  // MARK: - JSON value

  /// A JSON value with ordered object members, used to encode schemas.
  ///
  /// Objects keep their members in insertion order, so default-ordered encoders write keys in the
  /// order the schema emits them. (Apple's default order is hash order, so compare encoded schemas
  /// with `.sortedKeys`.)
  indirect enum JSONSchemaNode: Sendable, Equatable {
    /// A string.
    case string(String)

    /// An integer.
    case integer(Int)

    /// A floating-point number.
    case number(Double)

    /// A Boolean.
    case bool(Bool)

    /// An array.
    case array([JSONSchemaNode])

    /// An object, with members in insertion order.
    case object([Member])

    /// An object whose keys are names chosen by the schema's author (the `properties` and `$defs`
    /// maps) rather than JSON schema keywords.
    ///
    /// These maps are encoded as `[String: …]` dictionaries, and `JSONEncoder` never applies its
    /// `keyEncodingStrategy` to dictionary keys, so `.convertToSnakeCase` (or a custom strategy)
    /// leaves property and definition names alone while still converting keywords such as
    /// `additionalProperties`, as Apple's framework does. The members' order is therefore hash
    /// order unless the encoder sorts keys.
    case map([Member])

    /// A member of a JSON object.
    struct Member: Sendable, Equatable {
      /// The member's key.
      var key: String

      /// The member's value.
      var value: JSONSchemaNode
    }
  }

  /// A coding key with an arbitrary string value.
  struct JSONSchemaCodingKey: CodingKey, Hashable {
    /// The key's string value.
    var stringValue: String

    /// Always `nil`; schema keys are strings.
    var intValue: Int? { nil }

    /// Creates a key from a string.
    ///
    /// - Parameter stringValue: The key.
    init(stringValue: String) {
      self.stringValue = stringValue
    }

    /// Returns `nil`; schema keys are strings.
    ///
    /// - Parameter intValue: Ignored.
    init?(intValue: Int) {
      nil
    }
  }

  extension JSONSchemaNode: Encodable {
    /// Encodes this value into the given encoder.
    ///
    /// - Parameter encoder: The encoder to write data to.
    func encode(to encoder: any Encoder) throws {
      switch self {
      case .string(let value):
        var container = encoder.singleValueContainer()
        try container.encode(value)
      case .integer(let value):
        var container = encoder.singleValueContainer()
        try container.encode(value)
      case .number(let value):
        var container = encoder.singleValueContainer()
        try container.encode(value)
      case .bool(let value):
        var container = encoder.singleValueContainer()
        try container.encode(value)
      case .array(let elements):
        var container = encoder.unkeyedContainer()
        for element in elements {
          try container.encode(element)
        }
      case .object(let members):
        var container = encoder.container(keyedBy: JSONSchemaCodingKey.self)
        for member in members {
          try container.encode(member.value, forKey: JSONSchemaCodingKey(stringValue: member.key))
        }
      case .map(let members):
        var container = encoder.singleValueContainer()
        let dictionary = [String: JSONSchemaNode](
          members.map { ($0.key, $0.value) },
          uniquingKeysWith: { first, _ in first }
        )
        try container.encode(dictionary)
      }
    }
  }

  // MARK: - Schema → JSON

  extension GenerationSchema {
    /// Converts this schema to Apple's JSON schema format.
    ///
    /// Named objects and unions are hoisted into a root-level `$defs` and referenced with
    /// `{"$ref": "#/$defs/Name"}`; a reference back to the root is `{"$ref": "#"}`. Enumerations are
    /// always inlined. Only definitions reachable from the root are emitted.
    ///
    /// - Returns: The JSON schema.
    func jsonSchema() -> JSONSchemaNode {
      var builder = JSONSchemaBuilder(rootName: kind.definitionName)
      var members = builder.body(of: self, isRoot: true)
      if !builder.definitions.isEmpty {
        let definitions = builder.definitions.map { definition in
          JSONSchemaNode.Member(key: definition.name, value: definition.body ?? .object([]))
        }
        members.append(JSONSchemaNode.Member(key: "$defs", value: .map(definitions)))
      }
      return .object(members)
    }
  }

  /// Walks a schema tree, collecting `$defs` while producing JSON.
  private struct JSONSchemaBuilder {
    /// A hoisted definition; `body` is `nil` while the definition is being built.
    struct Definition {
      /// The definition's name.
      var name: String

      /// The definition's JSON, once built.
      var body: JSONSchemaNode?
    }

    /// The name of the root type, which nested references point at with `#`.
    let rootName: String?

    /// The hoisted definitions, in the order they were first referenced.
    var definitions: [Definition] = []

    /// Creates a builder for a schema whose root has the given definition name.
    ///
    /// - Parameter rootName: The root's name if it's an object or union.
    init(rootName: String?) {
      self.rootName = rootName
    }

    /// Returns the JSON for a schema used inside another schema, hoisting named types.
    ///
    /// Definitions are keyed by the type's short name (`String(describing:)`), exactly like
    /// Apple's: two different types with the same name (for example `A.Item` and `B.Item`) share
    /// the first definition encountered, and a nested type named like the root becomes
    /// `{"$ref": "#"}`.
    ///
    /// - Parameter schema: The nested schema.
    /// - Returns: The schema's JSON or a `$ref` to it.
    mutating func node(for schema: GenerationSchema) -> JSONSchemaNode {
      guard let name = schema.kind.definitionName else {
        return .object(body(of: schema, isRoot: false))
      }
      if name == rootName {
        return reference("#")
      }
      if !definitions.contains(where: { $0.name == name }) {
        let index = definitions.count
        definitions.append(Definition(name: name, body: nil))
        let definition = body(of: schema, isRoot: true)
        definitions[index].body = .object(definition)
      }
      return reference("#/$defs/\(name)")
    }

    /// Returns a `$ref` object.
    ///
    /// - Parameter target: The reference target.
    /// - Returns: `{"$ref": target}`.
    func reference(_ target: String) -> JSONSchemaNode {
      .object([JSONSchemaNode.Member(key: "$ref", value: .string(target))])
    }

    /// Returns the members of a schema's JSON object.
    ///
    /// - Parameters:
    ///   - schema: The schema.
    ///   - isRoot: Whether the schema is the root or a `$defs` entry, which carry their `title`
    ///     and `description`. Inlined enumerations lose both.
    /// - Returns: The JSON object members.
    mutating func body(of schema: GenerationSchema, isRoot: Bool) -> [JSONSchemaNode.Member] {
      var members: [JSONSchemaNode.Member] = []
      func add(_ key: String, _ value: JSONSchemaNode?) {
        guard let value else { return }
        members.append(JSONSchemaNode.Member(key: key, value: value))
      }
      switch schema.kind {
      case .structure(let structure):
        add("title", structure.name.isEmpty ? nil : .string(structure.name))
        add("description", structure.description.map(JSONSchemaNode.string))
        add("type", .string("object"))
        var properties: [JSONSchemaNode.Member] = []
        for property in structure.properties {
          properties.append(JSONSchemaNode.Member(key: property.name, value: node(for: property)))
        }
        add("properties", .map(properties))
        let required = structure.properties.filter { !$0.isOptional }.map(\.name)
        add("required", .array(required.map(JSONSchemaNode.string)))
        add("additionalProperties", .bool(false))
        add("x-order", .array(structure.properties.map { JSONSchemaNode.string($0.name) }))
      case .union(let union):
        add("title", union.name.isEmpty ? nil : .string(union.name))
        add("description", union.description.map(JSONSchemaNode.string))
        add("anyOf", .array(union.cases.map { node(for: $0.schema) }))
      case .enumeration(let enumeration):
        if isRoot {
          add("title", .string(enumeration.name))
          add("description", enumeration.description.map(JSONSchemaNode.string))
        }
        add("type", .string("string"))
        add("enum", .array(enumeration.cases.map(JSONSchemaNode.string)))
      case .string(let guides):
        add("type", .string("string"))
        add("pattern", guides.pattern.map(JSONSchemaNode.string))
        add("enum", guides.choices.map { .array($0.map(JSONSchemaNode.string)) })
      case .integer(let guides):
        add("type", .string("integer"))
        add("minimum", guides.minimum.map(JSONSchemaNode.integer))
        add("maximum", guides.maximum.map(JSONSchemaNode.integer))
      case .double(let guides):
        add("type", .string("number"))
        add("minimum", guides.minimum.map(JSONSchemaNode.number))
        add("maximum", guides.maximum.map(JSONSchemaNode.number))
      case .bool:
        add("type", .string("boolean"))
      case .null:
        add("type", .string("null"))
      case .constant(let value):
        add("const", .string(value))
      case .array(let array):
        add("type", .string("array"))
        add("items", node(for: array.element.schema))
        add("minItems", array.minimumCount.map(JSONSchemaNode.integer))
        add("maxItems", array.maximumCount.map(JSONSchemaNode.integer))
      case .dictionary(let dictionary):
        add("type", .string("object"))
        add("additionalProperties", node(for: dictionary.value.schema))
      }
      return members
    }

    /// Returns the JSON for an object property: its constrained schema plus its description.
    ///
    /// - Parameter property: The property.
    /// - Returns: The property's JSON.
    mutating func node(for property: GenerationSchema.Property) -> JSONSchemaNode {
      let value = node(for: property.resolvedSchema)
      guard let description = property.description, case .object(var members) = value else {
        return value
      }
      members.removeAll { $0.key == "description" }
      members.append(JSONSchemaNode.Member(key: "description", value: .string(description)))
      return .object(members)
    }
  }
#endif  // compiler(>=6.4)
