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


extension AgentPlatform {
  /// Defines the schema of input and output data. This is a subset of the [OpenAPI 3.0 Schema Object](https://spec.openapis.org/oas/v3.0.3#schema-object).
  public final class Schema: Codable, Sendable {
    /// Optional. If `type` is `OBJECT`, specifies how to handle properties not defined in `properties`. If it is a boolean `false`, no additional properties are allowed. If it is a schema, additional properties are allowed if they conform to the schema.
    public let additionalProperties: JSONValue?
    
    /// Optional. The instance must be valid against any (one or more) of the subschemas listed in `any_of`.
    public let anyOf: [Schema]?
    
    /// Optional. Default value to use if the field is not specified.
    public let `default`: JSONValue?
    
    /// Optional. `defs` provides a map of schema definitions that can be reused by `ref` elsewhere in the schema. Only allowed at root level of the schema.
    public let defs: [String: Schema]?
    
    /// Optional. Describes the data. The model uses this field to understand the purpose of the schema and how to use it. It is a best practice to provide a clear and descriptive explanation for the schema and its properties here, rather than in the prompt.
    public let description: String?
    
    /// Optional. Possible values of the field. This field can be used to restrict a value to a fixed set of values. To mark a field as an enum, set `format` to `enum` and provide the list of possible values in `enum`. For example: 1. To define directions: `{type:STRING, format:enum, enum:["EAST", "NORTH", "SOUTH", "WEST"]}` 2. To define apartment numbers: `{type:INTEGER, format:enum, enum:["101", "201", "301"]}`
    public let `enum`: [String]?
    
    /// Optional. Example of an instance of this schema.
    public let example: JSONValue?
    
    /// Optional. The format of the data. For `NUMBER` type, format can be `float` or `double`. For `INTEGER` type, format can be `int32` or `int64`. For `STRING` type, format can be `email`, `byte`, `date`, `date-time`, `password`, and other formats to further refine the data type.
    public let format: String?
    
    /// Optional. If type is `ARRAY`, `items` specifies the schema of elements in the array.
    public let items: Schema?
    
    /// Optional. If type is `ARRAY`, `max_items` specifies the maximum number of items in an array.
    public let maxItems: String?
    
    /// Optional. If type is `STRING`, `max_length` specifies the maximum length of the string.
    public let maxLength: String?
    
    /// Optional. If type is `OBJECT`, `max_properties` specifies the maximum number of properties that can be provided.
    public let maxProperties: String?
    
    /// Optional. If type is `INTEGER` or `NUMBER`, `maximum` specifies the maximum allowed value.
    public let maximum: Double?
    
    /// Optional. If type is `ARRAY`, `min_items` specifies the minimum number of items in an array.
    public let minItems: String?
    
    /// Optional. If type is `STRING`, `min_length` specifies the minimum length of the string.
    public let minLength: String?
    
    /// Optional. If type is `OBJECT`, `min_properties` specifies the minimum number of properties that can be provided.
    public let minProperties: String?
    
    /// Optional. If type is `INTEGER` or `NUMBER`, `minimum` specifies the minimum allowed value.
    public let minimum: Double?
    
    /// Optional. Indicates if the value of this field can be null.
    public let nullable: Bool?
    
    /// Optional. If type is `STRING`, `pattern` specifies a regular expression that the string must match.
    public let pattern: String?
    
    /// Optional. If type is `OBJECT`, `properties` is a map of property names to schema definitions for each property of the object.
    public let properties: [String: Schema]?
    
    /// Optional. Order of properties displayed or used where order matters. This is not a standard field in OpenAPI specification, but can be used to control the order of properties.
    public let propertyOrdering: [String]?
    
    /// Optional. Allows referencing another schema definition to use in place of this schema. The value must be a valid reference to a schema in `defs`. For example, the following schema defines a reference to a schema node named "Pet": type: object properties: pet: ref: #/defs/Pet defs: Pet: type: object properties: name: type: string The value of the "pet" property is a reference to the schema node named "Pet". See details in https://json-schema.org/understanding-json-schema/structuring
    public let ref: String?
    
    /// Optional. If type is `OBJECT`, `required` lists the names of properties that must be present.
    public let required: [String]?
    
    /// Optional. Title for the schema.
    public let title: String?
    
    /// Optional. Data type of the schema field.
    public let type: `Type`?
    
    /// Creates a new `Schema`.
    public init(
      additionalProperties: JSONValue? = nil,
      anyOf: [Schema]? = nil,
      `default`: JSONValue? = nil,
      defs: [String: Schema]? = nil,
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
      ref: String? = nil,
      required: [String]? = nil,
      title: String? = nil,
      type: `Type`? = nil
    ) {
      self.additionalProperties = additionalProperties
      self.anyOf = anyOf
      self.`default` = `default`
      self.defs = defs
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
      self.ref = ref
      self.required = required
      self.title = title
      self.type = type
    }
    enum CodingKeys: String, CodingKey {
      case additionalProperties = "additionalProperties"
      case anyOf = "anyOf"
      case `default` = "default"
      case defs = "defs"
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
      case ref = "ref"
      case required = "required"
      case title = "title"
      case type = "type"
    }
  }
}

// MARK: - Equatable & Hashable Conformance

extension AgentPlatform.Schema: Equatable, Hashable {
  public static func == (lhs: AgentPlatform.Schema, rhs: AgentPlatform.Schema) -> Bool {
    return
      lhs.additionalProperties == rhs.additionalProperties &&
      lhs.anyOf == rhs.anyOf &&
      lhs.`default` == rhs.`default` &&
      lhs.defs == rhs.defs &&
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
      lhs.ref == rhs.ref &&
      lhs.required == rhs.required &&
      lhs.title == rhs.title &&
      lhs.type == rhs.type
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(additionalProperties)
    hasher.combine(anyOf)
    hasher.combine(`default`)
    hasher.combine(defs)
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
    hasher.combine(ref)
    hasher.combine(required)
    hasher.combine(title)
    hasher.combine(type)
  }
}