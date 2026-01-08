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
    case string(name: String?, description: String?, guides: StringGuides)
    case integer(description: String?, guides: IntegerGuides)
    case double(description: String?, guides: DoubleGuides)
    case boolean(description: String?)
    case array(description: String?, item: any FirebaseGenerable.Type, guides: ArrayGuides)
    case object(name: String, description: String?, properties: [Property])
    case anyOf(name: String, description: String?, types: [any FirebaseGenerable.Type])
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
    let type: any FirebaseGenerable.Type
    let guides: AnyGenerationGuides

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
      self.name = name
      self.description = description
      isOptional = false
      self.type = Value.self
      self.guides = AnyGenerationGuides.combine(guides: guides)
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
      self.name = name
      self.description = description
      isOptional = true
      self.type = Value.self
      self.guides = AnyGenerationGuides.combine(guides: guides)
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
  }

  /// Creates a schema for a string enumeration.
  ///
  /// - Parameters:
  ///   - type: The type this schema represents.
  ///   - description: A natural language description of this schema.
  ///   - anyOf: The allowed choices.
  public init(type: any FirebaseGenerable.Type, description: String? = nil,
              anyOf choices: [String]) {
    let name = String(describing: type)
    kind = .string(name: name, description: description, guides: StringGuides(anyOf: choices))
    source = name
  }

  /// Creates a schema as the union of several other types.
  ///
  /// - Parameters:
  ///   - type: The type this schema represents.
  ///   - description: A natural language description of this schema.
  ///   - anyOf: The types this schema should be a union of.
  public init(type: any FirebaseGenerable.Type, description: String? = nil,
              anyOf types: [any FirebaseGenerable.Type]) {
    let name = String(describing: type)
    kind = .anyOf(name: name, description: description, types: types)
    source = name
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
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension JSONSchema: Encodable {
  public func encode(to encoder: any Encoder) throws {
    let definitions = collectDefinitions()

    let internalSchema = toInternal(
      definitions: definitions,
      isRoot: true
    )
    try internalSchema.encode(to: encoder)
  }

  func toInternal(definitions: [String: JSONSchema], isRoot: Bool,
                  defining: String? = nil) -> JSONSchema.Internal {
    // 1. Check if this schema should be a reference
    if let refSchema = makeRefSchema(definitions: definitions, isRoot: isRoot, defining: defining) {
      return refSchema
    }

    // 2. Prepare definitions if this is the root
    let defs = makeDefinitions(definitions: definitions, isRoot: isRoot)

    // 3. Convert based on kind
    return kind.toInternal(definitions: definitions, defs: defs)
  }

  private func makeRefSchema(definitions: [String: JSONSchema], isRoot: Bool,
                             defining: String?) -> JSONSchema.Internal? {
    if !isRoot, let name = name, definitions[name] != nil, name != defining {
      return JSONSchema.Internal(ref: "#/$defs/\(name)")
    }
    return nil
  }

  private func makeDefinitions(definitions: [String: JSONSchema],
                               isRoot: Bool) -> [String: JSONSchema.Internal]? {
    guard isRoot, !definitions.isEmpty else { return nil }
    var defs: [String: JSONSchema.Internal] = [:]
    for (name, def) in definitions {
      defs[name] = def.toInternal(definitions: definitions, isRoot: false, defining: name)
    }
    return defs
  }

  private func collectDefinitions() -> [String: JSONSchema] {
    var definitions: [String: JSONSchema] = [:]

    func visit(_ schema: JSONSchema, isRoot: Bool) {
      if !isRoot, let name = schema.name {
        // If we encounter a named schema that isn't the root, we collect it as a definition.
        if definitions[name] == nil {
          definitions[name] = schema
        }
      }

      // Traverse children
      switch schema.kind {
      case let .object(_, _, properties):
        for property in properties {
          visit(property.schema, isRoot: false)
        }
      case let .anyOf(_, _, types):
        for type in types {
          visit(type.jsonSchema, isRoot: false)
        }
      case let .array(_, item, _):
        visit(item.jsonSchema, isRoot: false)
      case .string, .integer, .double, .boolean:
        break
      }
    }

    visit(self, isRoot: true)
    return definitions
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension JSONSchema.Kind {
  func toInternal(definitions: [String: JSONSchema],
                  defs: [String: JSONSchema.Internal]?) -> JSONSchema.Internal {
    switch self {
    case let .object(name, description, properties):
      var props: [String: JSONSchema.Internal] = [:]
      var required: [String] = []
      var propertyOrder: [String] = []

      for property in properties {
        let propSchema = property.schema.toInternal(definitions: definitions, isRoot: false)
        props[property.name] = propSchema
        if !property.isOptional {
          required.append(property.name)
        }
        propertyOrder.append(property.name)
      }

      return JSONSchema.Internal(
        type: .object,
        title: name,
        description: description,
        properties: props,
        required: required.isEmpty ? nil : required,
        additionalProperties: false,
        defs: defs,
        order: propertyOrder
      )

    case let .anyOf(name, description, types):
      let anyOfSchemas = types.map { $0.jsonSchema.toInternal(
        definitions: definitions,
        isRoot: false
      ) }
      return JSONSchema.Internal(
        title: name,
        description: description,
        defs: defs,
        anyOf: anyOfSchemas
      )

    case let .array(description, item, guides):
      let itemSchema = item.jsonSchema.toInternal(definitions: definitions, isRoot: false)

      return JSONSchema.Internal(
        type: .array,
        description: description,
        defs: defs,
        items: itemSchema,
        minItems: guides.minimumCount,
        maxItems: guides.maximumCount
      )

    case let .string(name, description, guides):
      return JSONSchema.Internal(
        type: .string,
        title: name,
        description: description,
        defs: defs,
        enumValues: guides.anyOf?.map { .string($0) }
      )

    case let .integer(description, guides):
      return JSONSchema.Internal(
        type: .integer,
        description: description,
        defs: defs,
        minimum: guides.minimum.map(Double.init),
        maximum: guides.maximum.map(Double.init)
      )

    case let .double(description, guides):
      return JSONSchema.Internal(
        type: .number,
        description: description,
        defs: defs,
        minimum: guides.minimum,
        maximum: guides.maximum
      )

    case let .boolean(description):
      return JSONSchema.Internal(
        type: .boolean,
        description: description,
        defs: defs
      )
    }
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
private extension JSONSchema {
  var name: String? {
    switch kind {
    case let .object(name, _, _): return name
    case let .anyOf(name, _, _): return name
    case let .string(name, _, _): return name
    default: return nil
    }
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
private extension JSONSchema.Property {
  var schema: JSONSchema {
    return type.jsonSchema
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension JSONSchema {
  final class Internal {
    var type: JSONSchema.Internal.SchemaType?
    var title: String?
    var description: String?
    var properties: [String: JSONSchema.Internal]?
    var required: [String]?
    var additionalProperties: Bool?
    var defs: [String: JSONSchema.Internal]?
    var ref: String?
    var anyOf: [JSONSchema.Internal]?
    var items: JSONSchema.Internal?
    var minItems: Int?
    var maxItems: Int?
    var enumValues: [JSONValue]?
    var pattern: String?
    var minimum: Double?
    var maximum: Double?
    var order: [String]?

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
