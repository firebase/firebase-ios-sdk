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
#if canImport(FoundationModels)
  import FoundationModels
#endif // canImport(FoundationModels)

/// A type that describes the properties of an object and any guides on their values.
///
/// Generation  schemas guide the output of the model to deterministically ensure the output is in
/// the desired format.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct JSONSchema: Sendable {
  enum Kind: Sendable {
    case string
    case integer
    case double
    case boolean
    case array(item: any FirebaseGenerable.Type)
    case object(name: String, description: String?, properties: [Property])
  }

  let kind: Kind?
  let source: String?
  let schema: JSONSchema.Internal?

  init(kind: Kind, source: String) {
    self.kind = kind
    self.source = source
    schema = nil
  }

  /// A property that belongs to a JSON schema.
  ///
  /// Fields are named members of object types. Fields are strongly typed and have optional
  /// descriptions and guides.
  public struct Property: Sendable {
    let name: String
    let description: String?
    let isOptional: Bool
    let type: any FirebaseGenerable.Type
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
                       guides: [GenerationGuide<Value>] = []) where Value: FirebaseGenerable {
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
                       guides: [GenerationGuide<Value>] = []) where Value: FirebaseGenerable {
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
  public init(type: any FirebaseGenerable.Type, description: String? = nil,
              properties: [JSONSchema.Property]) {
    let name = String(describing: type)
    kind = .object(name: name, description: description, properties: properties)
    source = name
    schema = nil
  }

  /// Creates a schema for a string enumeration.
  ///
  /// - Parameters:
  ///   - type: The type this schema represents.
  ///   - description: A natural language description of this schema.
  ///   - anyOf: The allowed choices.
  public init(type: any FirebaseGenerable.Type, description: String? = nil,
              anyOf choices: [String]) {
    fatalError("`GenerationSchema.init(type:description:anyOf:)` is not implemented.")
  }

  /// Creates a schema as the union of several other types.
  ///
  /// - Parameters:
  ///   - type: The type this schema represents.
  ///   - description: A natural language description of this schema.
  ///   - anyOf: The types this schema should be a union of.
  public init(type: any FirebaseGenerable.Type, description: String? = nil,
              anyOf types: [any FirebaseGenerable.Type]) {
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

  func asGeminiJSONSchema() throws -> JSONObject {
    let jsonRepresentation = try JSONEncoder().encode(self)
    return try JSONDecoder().decode(JSONObject.self, from: jsonRepresentation)
  }

  private func makeInternal() -> Internal {
    if let schema {
      return schema
    }
    guard let kind else {
      fatalError("JSONSchema must have either `schema` or `kind`.")
    }
    return kind.makeInternal()
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension JSONSchema.Kind {
  func makeInternal() -> JSONSchema.Internal {
    switch self {
    case .string:
      return JSONSchema.Internal(type: .string)
    case .integer:
      return JSONSchema.Internal(type: .integer)
    case .double:
      return JSONSchema.Internal(type: .number)
    case .boolean:
      return JSONSchema.Internal(type: .boolean)
    case let .array(item):
      // Recursive call for array items
      return JSONSchema.Internal(type: .array, items: item.jsonSchema.makeInternal())
    case let .object(name, description, properties):
      let internalProperties = Dictionary(uniqueKeysWithValues: properties.map {
        ($0.name, $0.type.jsonSchema.makeInternal())
      })
      let required = properties.compactMap { $0.isOptional ? nil : $0.name }
      let order = properties.map { $0.name }
      return JSONSchema.Internal(
        type: .object,
        title: name,
        description: description,
        properties: internalProperties,
        required: required.isEmpty ? nil : required,
        order: order
      )
    }
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension JSONSchema: Codable {
  public init(from decoder: Decoder) throws {
    schema = try JSONSchema.Internal(from: decoder)
    // TODO: Populate `kind` using the decoded `JSONSchema.Internal`.
    kind = nil
    source = nil
  }

  public func encode(to encoder: any Encoder) throws {
    let schemaToEncode = makeInternal()
    try schemaToEncode.encode(to: encoder)
  }
}

#if canImport(FoundationModels)
  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  extension JSONSchema {
    func asGenerationSchema() throws -> FoundationModels.GenerationSchema {
      let jsonRepresentation = try JSONEncoder().encode(schema)
      return try JSONDecoder().decode(GenerationSchema.self, from: jsonRepresentation)
    }
  }
#endif // canImport(FoundationModels)

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension JSONSchema {
  final class Internal: Sendable {
    let type: JSONSchema.Internal.SchemaType?
    let title: String?
    let description: String?
    let properties: [String: JSONSchema.Internal]?
    let required: [String]?
    let additionalProperties: Bool?
    let defs: [String: JSONSchema.Internal]?
    let ref: String?
    let anyOf: [JSONSchema.Internal]?
    let items: JSONSchema.Internal?
    let minItems: Int?
    let maxItems: Int?
    let enumValues: [JSONValue]?
    let pattern: String?
    let minimum: Double?
    let maximum: Double?
    let order: [String]?

    init(type: JSONSchema.Internal.SchemaType? = nil,
         title: String? = nil,
         description: String? = nil,
         properties: [String: JSONSchema.Internal]? = nil,
         required: [String]? = nil,
         additionalProperties: Bool? = nil,
         defs: [String: JSONSchema.Internal]? = nil,
         ref: String? = nil,
         anyOf: [JSONSchema.Internal]? = nil,
         items: JSONSchema.Internal? = nil,
         minItems: Int? = nil,
         maxItems: Int? = nil,
         enumValues: [JSONValue]? = nil,
         pattern: String? = nil,
         minimum: Double? = nil,
         maximum: Double? = nil,
         order: [String]? = nil) {
      self.type = type
      self.title = title
      self.description = description
      self.properties = properties
      self.required = required
      self.additionalProperties = additionalProperties
      self.defs = defs
      self.ref = ref
      self.anyOf = anyOf
      self.items = items
      self.minItems = minItems
      self.maxItems = maxItems
      self.enumValues = enumValues
      self.pattern = pattern
      self.minimum = minimum
      self.maximum = maximum
      self.order = order
    }
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension JSONSchema.Internal {
  enum SchemaType: String, Codable, Sendable, Equatable {
    case object
    case array
    case string
    case integer
    case number
    case boolean
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension JSONSchema.Internal: Codable {
  enum CodingKeys: String, CodingKey {
    case type
    case title
    case description
    case properties
    case required
    case additionalProperties
    case defs = "$defs"
    case ref = "$ref"
    case anyOf
    case items
    case minItems
    case maxItems
    case enumValues = "enum"
    case pattern
    case minimum
    case maximum
    case order = "propertyOrdering"
  }
}
