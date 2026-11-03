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

  // MARK: - JSON → schema

  extension GenerationSchema {
    /// Decodes a schema from Apple's JSON schema format.
    ///
    /// Decoding is strict, like Apple's: every node needs one of `type`, `const`, `$ref`, or
    /// `anyOf`; `type` must be a single string; and objects need `x-order` and
    /// `additionalProperties`. References resolve against the root-level `$defs` (`#/$defs/Name`)
    /// or the root itself (`#`).
    ///
    /// - Parameter decoder: The decoder to read from.
    /// - Returns: The decoded schema.
    /// - Throws: `DecodingError` if the JSON isn't a valid schema.
    static func decodeRoot(from decoder: any Decoder) throws -> GenerationSchema {
      let root = try DecodedSchemaNode(from: decoder).schema
      let container = try decoder.container(keyedBy: JSONSchemaCodingKey.self)
      let definitionsKey = JSONSchemaCodingKey(stringValue: "$defs")
      var names: [String?] = []
      var dependencies: [DynamicGenerationSchema] = []
      if container.contains(definitionsKey) {
        // Decoded as a dictionary, so a `keyDecodingStrategy` doesn't rewrite the definition names
        // that `$ref`s point at.
        let definitions = try container.decode(
          [String: DecodedSchemaNode].self,
          forKey: definitionsKey
        )
        for (name, definition) in definitions {
          names.append(name)
          dependencies.append(definition.schema)
        }
      }
      do {
        return try DynamicGenerationSchema.resolve(
          root: root,
          dependencies: dependencies,
          dependencyNames: names
        )
      } catch let error as SchemaError {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: error.errorDescription ?? "Invalid schema",
            underlyingError: error
          )
        )
      }
    }
  }

  /// A JSON schema node decoded into a dynamic schema, whose references resolve later.
  private struct DecodedSchemaNode: Decodable {
    /// The JSON `type` values a schema node may have.
    ///
    /// An unknown value fails with a `DecodingError` that names this type.
    enum `Type`: String, Decodable {
      /// `"object"`.
      case object
      /// `"array"`.
      case array
      /// `"string"`.
      case string
      /// `"integer"`.
      case integer
      /// `"number"`.
      case number
      /// `"boolean"`.
      case boolean
      /// `"null"`.
      case null
    }

    /// The keys of a JSON schema node.
    ///
    /// Named `CodingKeys` so that missing-key errors match Apple's framework.
    enum CodingKeys: String, CodingKey {
      /// `type`.
      case type
      /// `title`.
      case title
      /// `description`.
      case description
      /// `properties`.
      case properties
      /// `required`.
      case required
      /// `additionalProperties`.
      case additionalProperties
      /// `x-order`.
      case order = "x-order"
      /// `items`.
      case items
      /// `minItems`.
      case minItems
      /// `maxItems`.
      case maxItems
      /// `minimum`.
      case minimum
      /// `maximum`.
      case maximum
      /// `enum`.
      case choices = "enum"
      /// `const`.
      case constant = "const"
      /// `pattern`.
      case pattern
      /// `anyOf`.
      case anyOf
      /// `$ref`.
      case reference = "$ref"
    }

    /// The decoded schema.
    let schema: DynamicGenerationSchema

    /// Decodes a schema node.
    ///
    /// - Parameter decoder: The decoder to read from.
    /// - Throws: `DecodingError` if the node isn't a valid schema.
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: DecodedSchemaNode.CodingKeys.self)
      if let reference = try container.decodeIfPresent(String.self, forKey: .reference) {
        schema = try Self.reference(reference, in: container)
      } else if container.contains(.anyOf) {
        schema = DynamicGenerationSchema(
          kind: .union(
            name: try container.decodeIfPresent(String.self, forKey: .title) ?? "",
            description: try container.decodeIfPresent(String.self, forKey: .description),
            choices: try container.decode([DecodedSchemaNode].self, forKey: .anyOf).map(\.schema)
          )
        )
      } else if container.contains(.constant) {
        let value = try container.decode(String.self, forKey: .constant)
        schema = DynamicGenerationSchema(kind: .schema(GenerationSchema(kind: .constant(value))))
      } else if container.contains(.type) {
        schema = try Self.typed(try container.decode(Type.self, forKey: .type), in: container)
      } else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription:
              "A schema node needs one of these keys: 'type', 'const', '$ref', or 'anyOf'."
          )
        )
      }
    }

    /// Decodes a `$ref` node.
    ///
    /// - Parameters:
    ///   - reference: The reference target.
    ///   - container: The node's container.
    /// - Returns: A reference schema.
    /// - Throws: `DecodingError` if the target isn't `#` or `#/$defs/Name`.
    private static func reference(
      _ reference: String,
      in container: KeyedDecodingContainer<DecodedSchemaNode.CodingKeys>
    ) throws -> DynamicGenerationSchema {
      let definitionsPrefix = "#/$defs/"
      if reference == "#" {
        return DynamicGenerationSchema(kind: .rootReference)
      }
      guard reference.hasPrefix(definitionsPrefix) else {
        throw DecodingError.dataCorruptedError(
          forKey: .reference,
          in: container,
          debugDescription: "Unsupported reference \(reference)"
        )
      }
      let name = String(reference.dropFirst(definitionsPrefix.count))
      return DynamicGenerationSchema(referenceTo: name)
    }

    /// Decodes a node that has a `type`.
    ///
    /// - Parameters:
    ///   - type: The node's type.
    ///   - container: The node's container.
    /// - Returns: The decoded schema.
    /// - Throws: `DecodingError` if a required key is missing or has the wrong type.
    private static func typed(
      _ type: Type,
      in container: KeyedDecodingContainer<DecodedSchemaNode.CodingKeys>
    ) throws -> DynamicGenerationSchema {
      switch type {
      case .object:
        return try object(in: container)
      case .array:
        return DynamicGenerationSchema(
          kind: .array(
            element: try container.decode(DecodedSchemaNode.self, forKey: .items).schema,
            minimumCount: try container.decodeIfPresent(Int.self, forKey: .minItems),
            maximumCount: try container.decodeIfPresent(Int.self, forKey: .maxItems)
          )
        )
      case .string:
        let choices = try container.decodeIfPresent([String].self, forKey: .choices)
        if let choices, let title = try container.decodeIfPresent(String.self, forKey: .title) {
          return DynamicGenerationSchema(
            kind: .enumeration(
              name: title,
              description: try container.decodeIfPresent(String.self, forKey: .description),
              cases: choices
            )
          )
        }
        let guides = GenerationSchema.StringGuides(
          choices: choices,
          pattern: try container.decodeIfPresent(String.self, forKey: .pattern)
        )
        return DynamicGenerationSchema(kind: .schema(GenerationSchema(kind: .string(guides))))
      case .integer:
        let guides = GenerationSchema.IntegerGuides(
          minimum: try container.decodeIfPresent(Int.self, forKey: .minimum),
          maximum: try container.decodeIfPresent(Int.self, forKey: .maximum)
        )
        return DynamicGenerationSchema(kind: .schema(GenerationSchema(kind: .integer(guides))))
      case .number:
        let guides = GenerationSchema.DoubleGuides(
          minimum: try container.decodeIfPresent(Double.self, forKey: .minimum),
          maximum: try container.decodeIfPresent(Double.self, forKey: .maximum)
        )
        return DynamicGenerationSchema(kind: .schema(GenerationSchema(kind: .double(guides))))
      case .boolean:
        return DynamicGenerationSchema(kind: .schema(GenerationSchema._boolean))
      case .null:
        return .null
      }
    }

    /// Decodes an object node: a structure, or a dictionary when `additionalProperties` is a
    /// schema.
    ///
    /// - Parameter container: The node's container.
    /// - Returns: The decoded schema.
    /// - Throws: `DecodingError.keyNotFound` if `x-order` or `additionalProperties` is missing.
    private static func object(
      in container: KeyedDecodingContainer<DecodedSchemaNode.CodingKeys>
    ) throws -> DynamicGenerationSchema {
      if container.contains(.additionalProperties),
        (try? container.decode(Bool.self, forKey: .additionalProperties)) == nil
      {
        let value = try container.decode(DecodedSchemaNode.self, forKey: .additionalProperties)
        return DynamicGenerationSchema(kind: .dictionary(value: value.schema))
      }
      // The properties are decoded before `x-order` and `additionalProperties` are checked, so a
      // malformed property is reported first.
      //
      // The properties are decoded as a dictionary, so a `keyDecodingStrategy` (such as
      // `.convertFromSnakeCase`) doesn't rewrite property names that `x-order` and `required` list
      // verbatim.
      var decodedProperties: [String: DecodedProperty] = [:]
      if container.contains(.properties) {
        decodedProperties = try container.decode(
          [String: DecodedProperty].self, forKey: .properties)
      }
      let required = try container.decodeIfPresent([String].self, forKey: .required) ?? []
      let order = try container.decode([String].self, forKey: .order)
      _ = try container.decode(Bool.self, forKey: .additionalProperties)
      var properties: [DynamicGenerationSchema.Property] = []
      for name in order {
        guard let property = decodedProperties[name] else {
          throw DecodingError.dataCorruptedError(
            forKey: .order,
            in: container,
            debugDescription: "x-order names \(name), which isn't in properties"
          )
        }
        properties.append(
          DynamicGenerationSchema.Property(
            name: name,
            description: property.description,
            schema: property.schema,
            isOptional: !required.contains(name)
          )
        )
      }
      return DynamicGenerationSchema(
        kind: .structure(
          name: try container.decodeIfPresent(String.self, forKey: .title) ?? "",
          description: try container.decodeIfPresent(String.self, forKey: .description),
          representsNilExplicitly: false,
          properties: properties
        )
      )
    }
  }

  /// An object property decoded from a schema node.
  ///
  /// A `description` next to a `title` belongs to the named type; otherwise it's the property's.
  private struct DecodedProperty: Decodable {
    /// The property's schema.
    let schema: DynamicGenerationSchema

    /// The property's description.
    let description: String?

    /// Decodes a property.
    ///
    /// - Parameter decoder: The decoder to read from.
    /// - Throws: `DecodingError` if the node isn't a valid schema.
    init(from decoder: any Decoder) throws {
      schema = try DecodedSchemaNode(from: decoder).schema
      let container = try decoder.container(keyedBy: DecodedSchemaNode.CodingKeys.self)
      if container.contains(.title) {
        description = nil
      } else {
        description = try container.decodeIfPresent(String.self, forKey: .description)
      }
    }
  }
#endif  // compiler(>=6.4)
