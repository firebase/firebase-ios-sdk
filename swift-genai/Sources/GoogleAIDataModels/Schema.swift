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
public import SharedDataModels


extension GoogleAI {
  /// The `Schema` object allows the definition of input and output data types. These types can be objects, but also primitives and arrays. Represents a select subset of an [OpenAPI 3.0 schema object](https://spec.openapis.org/oas/v3.0.3#schema).
  public final class Schema: Codable, Sendable {
    /// Optional. The value should be validated against any (one or more) of the subschemas in the list.
    public let anyOf: [Schema]?
    
    /// Optional. Default value of the field. Per JSON Schema, this field is intended for documentation generators and doesn't affect validation. Thus it's included here and ignored so that developers who send schemas with a `default` field don't get unknown-field errors.
    public let `default`: JSONValue?
    
    /// Optional. A brief description of the parameter. This could contain examples of use. Parameter description may be formatted as Markdown.
    public let description: String?
    
    /// Optional. Possible values of the element of Type.STRING with enum format. For example we can define an Enum Direction as : {type:STRING, format:enum, enum:["EAST", NORTH", "SOUTH", "WEST"]}
    public let `enum`: [String]?
    
    /// Optional. Example of the object. Will only populated when the object is the root.
    public let example: JSONValue?
    
    /// Optional. The format of the data. Any value is allowed, but most do not trigger any special functionality.
    public let format: String?
    
    /// Optional. Schema of the elements of Type.ARRAY.
    public let items: Schema?
    
    /// Optional. Maximum number of the elements for Type.ARRAY.
    public let maxItems: String?
    
    /// Optional. Maximum length of the Type.STRING
    public let maxLength: String?
    
    /// Optional. Maximum number of the properties for Type.OBJECT.
    public let maxProperties: String?
    
    /// Optional. Maximum value of the Type.INTEGER and Type.NUMBER
    public let maximum: Double?
    
    /// Optional. Minimum number of the elements for Type.ARRAY.
    public let minItems: String?
    
    /// Optional. SCHEMA FIELDS FOR TYPE STRING Minimum length of the Type.STRING
    public let minLength: String?
    
    /// Optional. Minimum number of the properties for Type.OBJECT.
    public let minProperties: String?
    
    /// Optional. SCHEMA FIELDS FOR TYPE INTEGER and NUMBER Minimum value of the Type.INTEGER and Type.NUMBER
    public let minimum: Double?
    
    /// Optional. Indicates if the value may be null.
    public let nullable: Bool?
    
    /// Optional. Pattern of the Type.STRING to restrict a string to a regular expression.
    public let pattern: String?
    
    /// Optional. Properties of Type.OBJECT.
    public let properties: [String: Schema]?
    
    /// Optional. The order of the properties. Not a standard field in open api spec. Used to determine the order of the properties in the response.
    public let propertyOrdering: [String]?
    
    /// Optional. Required properties of Type.OBJECT.
    public let required: [String]?
    
    /// Optional. The title of the schema.
    public let title: String?
    
    /// Required. Data type.
    public let type: `Type`?
    
    /// Creates a new `Schema`.
    public init(
      anyOf: [Schema]? = nil,
      `default`: JSONValue? = nil,
      description: String? = nil,
      `enum`: [String]? = nil,
      example: JSONValue? = nil,
      format: String? = nil,
      items: Schema? = nil,
      maxItems: String? = nil,
      maxLength: String? = nil,
      maxProperties: String? = nil,
      maximum: Double? = nil,
      minItems: String? = nil,
      minLength: String? = nil,
      minProperties: String? = nil,
      minimum: Double? = nil,
      nullable: Bool? = nil,
      pattern: String? = nil,
      properties: [String: Schema]? = nil,
      propertyOrdering: [String]? = nil,
      required: [String]? = nil,
      title: String? = nil,
      type: `Type`? = nil
    ) {
      self.anyOf = anyOf
      self.`default` = `default`
      self.description = description
      self.`enum` = `enum`
      self.example = example
      self.format = format
      self.items = items
      self.maxItems = maxItems
      self.maxLength = maxLength
      self.maxProperties = maxProperties
      self.maximum = maximum
      self.minItems = minItems
      self.minLength = minLength
      self.minProperties = minProperties
      self.minimum = minimum
      self.nullable = nullable
      self.pattern = pattern
      self.properties = properties
      self.propertyOrdering = propertyOrdering
      self.required = required
      self.title = title
      self.type = type
    }
    enum CodingKeys: String, CodingKey {
      case anyOf = "anyOf"
      case `default` = "default"
      case description = "description"
      case `enum` = "enum"
      case example = "example"
      case format = "format"
      case items = "items"
      case maxItems = "maxItems"
      case maxLength = "maxLength"
      case maxProperties = "maxProperties"
      case maximum = "maximum"
      case minItems = "minItems"
      case minLength = "minLength"
      case minProperties = "minProperties"
      case minimum = "minimum"
      case nullable = "nullable"
      case pattern = "pattern"
      case properties = "properties"
      case propertyOrdering = "propertyOrdering"
      case required = "required"
      case title = "title"
      case type = "type"
    }
  }
}

// MARK: - Equatable & Hashable Conformance

extension GoogleAI.Schema: Equatable, Hashable {
  public static func == (lhs: GoogleAI.Schema, rhs: GoogleAI.Schema) -> Bool {
    return
      lhs.anyOf == rhs.anyOf &&
      lhs.`default` == rhs.`default` &&
      lhs.description == rhs.description &&
      lhs.`enum` == rhs.`enum` &&
      lhs.example == rhs.example &&
      lhs.format == rhs.format &&
      lhs.items == rhs.items &&
      lhs.maxItems == rhs.maxItems &&
      lhs.maxLength == rhs.maxLength &&
      lhs.maxProperties == rhs.maxProperties &&
      lhs.maximum == rhs.maximum &&
      lhs.minItems == rhs.minItems &&
      lhs.minLength == rhs.minLength &&
      lhs.minProperties == rhs.minProperties &&
      lhs.minimum == rhs.minimum &&
      lhs.nullable == rhs.nullable &&
      lhs.pattern == rhs.pattern &&
      lhs.properties == rhs.properties &&
      lhs.propertyOrdering == rhs.propertyOrdering &&
      lhs.required == rhs.required &&
      lhs.title == rhs.title &&
      lhs.type == rhs.type
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(anyOf)
    hasher.combine(`default`)
    hasher.combine(description)
    hasher.combine(`enum`)
    hasher.combine(example)
    hasher.combine(format)
    hasher.combine(items)
    hasher.combine(maxItems)
    hasher.combine(maxLength)
    hasher.combine(maxProperties)
    hasher.combine(maximum)
    hasher.combine(minItems)
    hasher.combine(minLength)
    hasher.combine(minProperties)
    hasher.combine(minimum)
    hasher.combine(nullable)
    hasher.combine(pattern)
    hasher.combine(properties)
    hasher.combine(propertyOrdering)
    hasher.combine(required)
    hasher.combine(title)
    hasher.combine(type)
  }
}