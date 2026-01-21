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

import Foundation

/// A type that describes the properties of an object and any guides on their values.
///
/// Generation  schemas guide the output of the model to deterministically ensure the output is in
/// the desired format.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct JSONSchema: Sendable, CustomDebugStringConvertible {
  enum Kind: Sendable, Equatable, Hashable {
    case string(guides: StringGuides)
    case integer(guides: IntegerGuides)
    case double(guides: DoubleGuides)
    case boolean
    case array(item: FirebaseGenerableType, guides: ArrayGuides)
    case object(properties: [Property])
    case anyOf(types: [FirebaseGenerableType])
  }

  let type: FirebaseGenerableType
  let kind: Kind
  let title: String?
  let description: String?

  init(type: any FirebaseGenerable.Type, kind: Kind, title: String? = nil,
       description: String? = nil) {
    self.kind = kind
    self.type = FirebaseGenerableType(type)
    self.title = title
    self.description = description
  }

  public struct Property: Sendable, Equatable, Hashable {
    let name: String
    let description: String?
    let isOptional: Bool
    let type: FirebaseGenerableType
    let guides: AnyGenerationGuides

    public init<Value>(name: String, description: String? = nil, type: Value.Type,
                       guides: [FirebaseGenerationGuide<Value>] = [])
      where Value: FirebaseGenerable {
      self.name = name
      self.description = description
      isOptional = false
      self.type = FirebaseGenerableType(Value.self)
      self.guides = AnyGenerationGuides.combine(guides: guides)
    }

    public init<Value>(name: String, description: String? = nil, type: Value?.Type,
                       guides: [FirebaseGenerationGuide<Value>] = [])
      where Value: FirebaseGenerable {
      self.name = name
      self.description = description
      isOptional = true
      self.type = FirebaseGenerableType(Value.self)
      self.guides = AnyGenerationGuides.combine(guides: guides)
    }
  }

  public init(type: any FirebaseGenerable.Type, description: String? = nil,
              properties: [JSONSchema.Property]) {
    self.init(
      type: type,
      kind: .object(properties: properties),
      title: String(describing: type),
      description: description
    )
  }

  public init(type: any FirebaseGenerable.Type, description: String? = nil,
              anyOf choices: [String]) {
    self.init(
      type: type,
      kind: .string(guides: StringGuides(anyOf: choices)),
      description: description
    )
  }

  public init(type: any FirebaseGenerable.Type, description: String? = nil,
              anyOf types: [any FirebaseGenerable.Type]) {
    self.init(
      type: type,
      kind: .anyOf(types: types.map { FirebaseGenerableType($0) }),
      title: String(describing: type),
      description: description
    )
  }

  public enum SchemaError: Error, LocalizedError {
    public struct Context: Sendable {
      public let debugDescription: String

      public init(debugDescription: String) {
        self.debugDescription = debugDescription
      }
    }

    case duplicateType(schema: String?, type: String, context: JSONSchema.SchemaError.Context)
    case duplicateProperty(
      schema: String,
      property: String,
      context: JSONSchema.SchemaError.Context
    )
    case emptyTypeChoices(schema: String, context: JSONSchema.SchemaError.Context)
    case undefinedReferences(
      schema: String?,
      references: [String],
      context: JSONSchema.SchemaError.Context
    )
    case circularDependency(
      type: String,
      context: JSONSchema.SchemaError.Context
    )
  }

  public var debugDescription: String {
    let schemaEncoder = SchemaEncoder(target: .gemini)
    do {
      let schema = try schemaEncoder.encode(self)
      let jsonEncoder = JSONEncoder()
      jsonEncoder.outputFormatting = [.prettyPrinted]
      let jsonData = try jsonEncoder.encode(schema)
      guard let jsonString = String(data: jsonData, encoding: .utf8) else {
        return "Error: Failed to encode JSONSchema (String conversion failed)"
      }
      return jsonString
    } catch {
      return "Error: Failed to encode JSONSchema (\(error))"
    }
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension JSONSchema {
  final class Internal: Codable {
    enum SchemaType: String, Codable {
      case object, array, string, integer, number, boolean
    }

    var type: SchemaType?
    var title: String?
    var description: String?
    var properties: [String: JSONSchema.Internal]?
    var format: String?
    var required: [String]?
    var additionalProperties: Bool?
    var defs: [String: JSONSchema.Internal]?
    var ref: String?
    var anyOf: [JSONSchema.Internal]?
    var items: JSONSchema.Internal?
    var minItems: Int?
    var maxItems: Int?
    var enumValues: [JSONValue]?
    var minimum: Double?
    var maximum: Double?
    var propertyOrdering: [String]?
    var xOrder: [String]?

    enum CodingKeys: String, CodingKey {
      case type, title, description, properties, format, required, additionalProperties
      case defs = "$defs"
      case ref = "$ref"
      case anyOf, items, minItems, maxItems
      case enumValues = "enum"
      case minimum, maximum
      case propertyOrdering
      case xOrder = "x-order"
    }

    init(type: SchemaType? = nil, ref: String? = nil, anyOf: [JSONSchema.Internal]? = nil) {
      self.type = type
      self.ref = ref
      self.anyOf = anyOf
    }
  }
}
