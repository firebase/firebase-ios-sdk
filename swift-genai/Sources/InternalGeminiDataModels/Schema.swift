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
package import InternalSharedDataModels


extension GeminiDataModels {
  /// The `Schema` object allows the definition of input and output data types. These types can be objects, but also primitives and arrays. Represents a select subset of an [OpenAPI 3.0 schema object](https://spec.openapis.org/oas/v3.0.3#schema).
  /// 
  /// Variant:
  /// Defines the schema of input and output data. This is a subset of the [OpenAPI 3.0 Schema Object](https://spec.openapis.org/oas/v3.0.3#schema-object).
  package final class Schema: Codable, Sendable {
    /// Optional. Minimum number of the properties for Type.OBJECT.
    /// 
    /// Variant:
    /// Optional. If type is `OBJECT`, `min_properties` specifies the minimum number of properties that can be provided.
    package let minProperties: String?
    
    /// Optional. A brief description of the parameter. This could contain examples of use. Parameter description may be formatted as Markdown.
    /// 
    /// Variant:
    /// Optional. Describes the data. The model uses this field to understand the purpose of the schema and how to use it. It is a best practice to provide a clear and descriptive explanation for the schema and its properties here, rather than in the prompt.
    package let description: String?
    
    /// Optional. The order of the properties. Not a standard field in open api spec. Used to determine the order of the properties in the response.
    /// 
    /// Variant:
    /// Optional. Order of properties displayed or used where order matters. This is not a standard field in OpenAPI specification, but can be used to control the order of properties.
    package let propertyOrdering: [String]?
    
    /// Required. Data type.
    /// 
    /// Variant:
    /// Optional. Data type of the schema field.
    package let type: `Type`?
    
    /// Optional. Minimum number of the elements for Type.ARRAY.
    /// 
    /// Variant:
    /// Optional. If type is `ARRAY`, `min_items` specifies the minimum number of items in an array.
    package let minItems: String?
    
    /// Optional. Indicates if the value may be null.
    /// 
    /// Variant:
    /// Optional. Indicates if the value of this field can be null.
    package let nullable: Bool?
    
    /// Optional. Required properties of Type.OBJECT.
    /// 
    /// Variant:
    /// Optional. If type is `OBJECT`, `required` lists the names of properties that must be present.
    package let required: [String]?
    
    /// Optional. The value should be validated against any (one or more) of the subschemas in the list.
    /// 
    /// Variant:
    /// Optional. The instance must be valid against any (one or more) of the subschemas listed in `any_of`.
    package let anyOf: [Schema]?
    
    /// Optional. Example of the object. Will only populated when the object is the root.
    /// 
    /// Variant:
    /// Optional. Example of an instance of this schema.
    package let example: JSONValue?
    
    /// Optional. Properties of Type.OBJECT.
    /// 
    /// Variant:
    /// Optional. If type is `OBJECT`, `properties` is a map of property names to schema definitions for each property of the object.
    package let properties: [String: Schema]?
    
    /// Optional. Possible values of the element of Type.STRING with enum format. For example we can define an Enum Direction as : {type:STRING, format:enum, enum:["EAST", NORTH", "SOUTH", "WEST"]}
    /// 
    /// Variant:
    /// Optional. Possible values of the field. This field can be used to restrict a value to a fixed set of values. To mark a field as an enum, set `format` to `enum` and provide the list of possible values in `enum`. For example: 1. To define directions: `{type:STRING, format:enum, enum:["EAST", "NORTH", "SOUTH", "WEST"]}` 2. To define apartment numbers: `{type:INTEGER, format:enum, enum:["101", "201", "301"]}`
    package let `enum`: [String]?
    
    /// Optional. Maximum number of the elements for Type.ARRAY.
    /// 
    /// Variant:
    /// Optional. If type is `ARRAY`, `max_items` specifies the maximum number of items in an array.
    package let maxItems: String?
    
    /// Optional. `defs` provides a map of schema definitions that can be reused by `ref` elsewhere in the schema. Only allowed at root level of the schema.
    /// 
    /// > Important: `defs` is only available in the Gemini Enterprise Agent Platform.
    package let defs: [String: Schema]?
    
    /// Optional. Maximum value of the Type.INTEGER and Type.NUMBER
    /// 
    /// Variant:
    /// Optional. If type is `INTEGER` or `NUMBER`, `maximum` specifies the maximum allowed value.
    package let maximum: Double?
    
    /// Optional. The format of the data. Any value is allowed, but most do not trigger any special functionality.
    /// 
    /// Variant:
    /// Optional. The format of the data. For `NUMBER` type, format can be `float` or `double`. For `INTEGER` type, format can be `int32` or `int64`. For `STRING` type, format can be `email`, `byte`, `date`, `date-time`, `password`, and other formats to further refine the data type.
    package let format: String?
    
    /// Optional. Schema of the elements of Type.ARRAY.
    /// 
    /// Variant:
    /// Optional. If type is `ARRAY`, `items` specifies the schema of elements in the array.
    package let items: Schema?
    
    /// Optional. SCHEMA FIELDS FOR TYPE STRING Minimum length of the Type.STRING
    /// 
    /// Variant:
    /// Optional. If type is `STRING`, `min_length` specifies the minimum length of the string.
    package let minLength: String?
    
    /// Optional. SCHEMA FIELDS FOR TYPE INTEGER and NUMBER Minimum value of the Type.INTEGER and Type.NUMBER
    /// 
    /// Variant:
    /// Optional. If type is `INTEGER` or `NUMBER`, `minimum` specifies the minimum allowed value.
    package let minimum: Double?
    
    /// Optional. The title of the schema.
    /// 
    /// Variant:
    /// Optional. Title for the schema.
    package let title: String?
    
    /// Optional. Allows referencing another schema definition to use in place of this schema. The value must be a valid reference to a schema in `defs`. For example, the following schema defines a reference to a schema node named "Pet": type: object properties: pet: ref: #/defs/Pet defs: Pet: type: object properties: name: type: string The value of the "pet" property is a reference to the schema node named "Pet". See details in https://json-schema.org/understanding-json-schema/structuring
    /// 
    /// > Important: `ref` is only available in the Gemini Enterprise Agent Platform.
    package let ref: String?
    
    /// Optional. Maximum number of the properties for Type.OBJECT.
    /// 
    /// Variant:
    /// Optional. If type is `OBJECT`, `max_properties` specifies the maximum number of properties that can be provided.
    package let maxProperties: String?
    
    /// Optional. Pattern of the Type.STRING to restrict a string to a regular expression.
    /// 
    /// Variant:
    /// Optional. If type is `STRING`, `pattern` specifies a regular expression that the string must match.
    package let pattern: String?
    
    /// Optional. If `type` is `OBJECT`, specifies how to handle properties not defined in `properties`. If it is a boolean `false`, no additional properties are allowed. If it is a schema, additional properties are allowed if they conform to the schema.
    /// 
    /// > Important: `additionalProperties` is only available in the Gemini Enterprise Agent Platform.
    package let additionalProperties: JSONValue?
    
    /// Optional. Maximum length of the Type.STRING
    /// 
    /// Variant:
    /// Optional. If type is `STRING`, `max_length` specifies the maximum length of the string.
    package let maxLength: String?
    
    /// Optional. Default value of the field. Per JSON Schema, this field is intended for documentation generators and doesn't affect validation. Thus it's included here and ignored so that developers who send schemas with a `default` field don't get unknown-field errors.
    /// 
    /// Variant:
    /// Optional. Default value to use if the field is not specified.
    package let `default`: JSONValue?
    
    /// Creates a new `Schema`.
    package init(
      minProperties: String? = nil,
      description: String? = nil,
      propertyOrdering: [String]? = nil,
      type: `Type`? = nil,
      minItems: String? = nil,
      nullable: Bool? = nil,
      required: [String]? = nil,
      anyOf: [Schema]? = nil,
      example: JSONValue? = nil,
      properties: [String: Schema]? = nil,
      `enum`: [String]? = nil,
      maxItems: String? = nil,
      defs: [String: Schema]? = nil,
      maximum: Double? = nil,
      format: String? = nil,
      items: Schema? = nil,
      minLength: String? = nil,
      minimum: Double? = nil,
      title: String? = nil,
      ref: String? = nil,
      maxProperties: String? = nil,
      pattern: String? = nil,
      additionalProperties: JSONValue? = nil,
      maxLength: String? = nil,
      `default`: JSONValue? = nil
    ) {
      self.minProperties = minProperties
      self.description = description
      self.propertyOrdering = propertyOrdering
      self.type = type
      self.minItems = minItems
      self.nullable = nullable
      self.required = required
      self.anyOf = anyOf
      self.example = example
      self.properties = properties
      self.`enum` = `enum`
      self.maxItems = maxItems
      self.defs = defs
      self.maximum = maximum
      self.format = format
      self.items = items
      self.minLength = minLength
      self.minimum = minimum
      self.title = title
      self.ref = ref
      self.maxProperties = maxProperties
      self.pattern = pattern
      self.additionalProperties = additionalProperties
      self.maxLength = maxLength
      self.`default` = `default`
    }
    enum CodingKeys: String, CodingKey {
      case minProperties = "minProperties"
      case description = "description"
      case propertyOrdering = "propertyOrdering"
      case type = "type"
      case minItems = "minItems"
      case nullable = "nullable"
      case required = "required"
      case anyOf = "anyOf"
      case example = "example"
      case properties = "properties"
      case `enum` = "enum"
      case maxItems = "maxItems"
      case defs = "defs"
      case maximum = "maximum"
      case format = "format"
      case items = "items"
      case minLength = "minLength"
      case minimum = "minimum"
      case title = "title"
      case ref = "ref"
      case maxProperties = "maxProperties"
      case pattern = "pattern"
      case additionalProperties = "additionalProperties"
      case maxLength = "maxLength"
      case `default` = "default"
    }
  }
}

// MARK: - Equatable & Hashable Conformance

extension GeminiDataModels.Schema: Equatable, Hashable {
  package static func == (lhs: GeminiDataModels.Schema, rhs: GeminiDataModels.Schema) -> Bool {
    return
      lhs.minProperties == rhs.minProperties &&
      lhs.description == rhs.description &&
      lhs.propertyOrdering == rhs.propertyOrdering &&
      lhs.type == rhs.type &&
      lhs.minItems == rhs.minItems &&
      lhs.nullable == rhs.nullable &&
      lhs.required == rhs.required &&
      lhs.anyOf == rhs.anyOf &&
      lhs.example == rhs.example &&
      lhs.properties == rhs.properties &&
      lhs.`enum` == rhs.`enum` &&
      lhs.maxItems == rhs.maxItems &&
      lhs.defs == rhs.defs &&
      lhs.maximum == rhs.maximum &&
      lhs.format == rhs.format &&
      lhs.items == rhs.items &&
      lhs.minLength == rhs.minLength &&
      lhs.minimum == rhs.minimum &&
      lhs.title == rhs.title &&
      lhs.ref == rhs.ref &&
      lhs.maxProperties == rhs.maxProperties &&
      lhs.pattern == rhs.pattern &&
      lhs.additionalProperties == rhs.additionalProperties &&
      lhs.maxLength == rhs.maxLength &&
      lhs.`default` == rhs.`default`
  }

  package func hash(into hasher: inout Hasher) {
    hasher.combine(minProperties)
    hasher.combine(description)
    hasher.combine(propertyOrdering)
    hasher.combine(type)
    hasher.combine(minItems)
    hasher.combine(nullable)
    hasher.combine(required)
    hasher.combine(anyOf)
    hasher.combine(example)
    hasher.combine(properties)
    hasher.combine(`enum`)
    hasher.combine(maxItems)
    hasher.combine(defs)
    hasher.combine(maximum)
    hasher.combine(format)
    hasher.combine(items)
    hasher.combine(minLength)
    hasher.combine(minimum)
    hasher.combine(title)
    hasher.combine(ref)
    hasher.combine(maxProperties)
    hasher.combine(pattern)
    hasher.combine(additionalProperties)
    hasher.combine(maxLength)
    hasher.combine(`default`)
  }
}