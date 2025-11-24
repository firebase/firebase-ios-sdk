// Copyright 2025 Google LLC
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

import Foundation

/// A type that describes the properties of an object and any guides on their values.
///
/// Generation  schemas guide the output of the model to deterministically ensure the output is in
/// the desired format.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct JSONSchema: Sendable {
  enum Kind {
    case string
    case integer
    case double
    case boolean
    case array(item: Generable.Type)
    case object(name: String, description: String?, properties: [Property])
  }

  let kind: Kind
  let source: String

  init(kind: Kind, source: String) {
    self.kind = kind
    self.source = source
  }

  /// A property that belongs to a JSON schema.
  ///
  /// Fields are named members of object types. Fields are strongly typed and have optional
  /// descriptions and guides.
  public struct Property: Sendable {
    let name: String
    let description: String?
    let isOptional: Bool
    let type: Generable.Type
    // TODO: Store `GenerationGuide` values.

    /// Create a property that contains a generable type.
    ///
    /// - Parameters:
    ///   - name: The property's name.
    ///   - description: A natural language description of what content should be generated for this
    ///     property.
    ///   - type: The type this property represents.
    ///   - guides: A list of guides to apply to this property.
    public init<Value>(name: String, description: String? = nil, type: Value.Type,
                       guides: [GenerationGuide<Value>] = []) where Value: Generable {
      precondition(guides.isEmpty, "GenerationGuide support is not yet implemented.")
      self.name = name
      self.description = description
      isOptional = false
      self.type = Value.self
    }

    /// Create an optional property that contains a generable type.
    ///
    /// - Parameters:
    ///   - name: The property's name.
    ///   - description: A natural language description of what content should be generated for this
    ///     property.
    ///   - type: The type this property represents.
    ///   - guides: A list of guides to apply to this property.
    public init<Value>(name: String, description: String? = nil, type: Value?.Type,
                       guides: [GenerationGuide<Value>] = []) where Value: Generable {
      precondition(guides.isEmpty, "GenerationGuide support is not yet implemented.")
      self.name = name
      self.description = description
      isOptional = true
      self.type = Value.self
    }
  }

  /// Creates a schema by providing an array of properties.
  ///
  /// - Parameters:
  ///   - type: The type this schema represents.
  ///   - description: A natural language description of this schema.
  ///   - properties: An array of properties.
  public init(type: any Generable.Type, description: String? = nil,
              properties: [JSONSchema.Property]) {
    let name = String(describing: type)
    kind = .object(name: name, description: description, properties: properties)
    source = name
  }

  /// Creates a schema for a string enumeration.
  ///
  /// - Parameters:
  ///   - type: The type this schema represents.
  ///   - description: A natural language description of this schema.
  ///   - anyOf: The allowed choices.
  public init(type: any Generable.Type, description: String? = nil, anyOf choices: [String]) {
    fatalError("`GenerationSchema.init(type:description:anyOf:)` is not implemented.")
  }

  /// Creates a schema as the union of several other types.
  ///
  /// - Parameters:
  ///   - type: The type this schema represents.
  ///   - description: A natural language description of this schema.
  ///   - anyOf: The types this schema should be a union of.
  public init(type: any Generable.Type, description: String? = nil,
              anyOf types: [any Generable.Type]) {
    fatalError("`GenerationSchema.init(type:description:anyOf:)` is not implemented.")
  }

  /// A error that occurs when there is a problem creating a JSON schema.
  public enum SchemaError: Error, LocalizedError {
    /// The context in which the error occurred.
    public struct Context: Sendable {
      /// A string representation of the debug description.
      ///
      /// This string is not localized and is not appropriate for display to end users.
      public let debugDescription: String

      public init(debugDescription: String) {
        self.debugDescription = debugDescription
      }
    }

    /// An error that represents an attempt to construct a schema from dynamic schemas, and two or
    /// more of the subschemas have the same type name.
    case duplicateType(schema: String?, type: String, context: JSONSchema.SchemaError.Context)

    /// An error that represents an attempt to construct a dynamic schema with properties that have
    /// conflicting names.
    case duplicateProperty(
      schema: String,
      property: String,
      context: JSONSchema.SchemaError.Context
    )

    /// An error that represents an attempt to construct an anyOf schema with an empty array of type
    /// choices.
    case emptyTypeChoices(schema: String, context: JSONSchema.SchemaError.Context)

    /// An error that represents an attempt to construct a schema from dynamic schemas, and one of
    /// those schemas references an undefined schema.
    case undefinedReferences(
      schema: String?,
      references: [String],
      context: JSONSchema.SchemaError.Context
    )

    /// A string representation of the error description.
    public var errorDescription: String? { nil }

    /// A suggestion that indicates how to handle the error.
    public var recoverySuggestion: String? { nil }
  }

  /// Returns an OpenAPI ``Schema`` equivalent of this JSON schema for testing.
  public func asOpenAPISchema() -> Schema {
    // TODO: Make this method internal or remove it when JSON Schema serialization is implemented.
    switch kind {
    case .string:
      return .string()
    case .integer:
      return .integer()
    case .double:
      return .double()
    case .boolean:
      return .boolean()
    case let .array(item: item):
      return .array(items: item.jsonSchema.asOpenAPISchema())
    case let .object(name: name, description: description, properties: properties):
      var objectProperties = [String: Schema]()
      for property in properties {
        objectProperties[property.name] = property.type.jsonSchema.asOpenAPISchema()
      }
      return .object(
        properties: objectProperties,
        optionalProperties: properties.compactMap { property in
          guard property.isOptional else { return nil }
          return property.name
        },
        propertyOrdering: properties.map { $0.name },
        description: description,
        title: name
      )
    }
  }
}
