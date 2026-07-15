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
  /// An internal data model for `Schema`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaSchema`
  /// 
  /// The `Schema` object allows the definition of input and output data types.
  /// These types can be objects, but also primitives and arrays.
  /// Represents a select subset of an [OpenAPI 3.0 schema
  /// object](https://spec.openapis.org/oas/v3.0.3#schema).
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1Schema`
  /// 
  /// Defines the schema of input and output data. This is a subset of the
  /// [OpenAPI 3.0 Schema
  /// Object](https://spec.openapis.org/oas/v3.0.3#schema-object).
  package final class Schema: Codable, Sendable {
    /// Required. Data type.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. Data type.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Data type of the schema field.
    package let type: DataType
    
    /// Optional. The format of the data. Any value is allowed, but most do not trigger any
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The format of the data. Any value is allowed, but most do not trigger any
    /// special functionality.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The format of the data.
    /// For `NUMBER` type, format can be `float` or `double`.
    /// For `INTEGER` type, format can be `int32` or `int64`.
    /// For `STRING` type, format can be `email`, `byte`, `date`, `date-time`,
    /// `password`, and other formats to further refine the data type.
    package let format: String?
    
    /// Optional. The title of the schema.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The title of the schema.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Title for the schema.
    package let title: String?
    
    /// Optional. A brief description of the parameter. This could contain examples of use.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. A brief description of the parameter. This could contain examples of use.
    /// Parameter description may be formatted as Markdown.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Describes the data. The model uses this field to understand
    /// the purpose of the schema and how to use it. It is a best practice to
    /// provide a clear and descriptive explanation for the schema and its
    /// properties here, rather than in the prompt.
    package let description: String?
    
    /// Optional. Indicates if the value may be null.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Indicates if the value may be null.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Indicates if the value of this field can be null.
    package let nullable: Bool?
    
    /// Optional. Possible values of the element of Type.STRING with enum format.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Possible values of the element of Type.STRING with enum format.
    /// For example we can define an Enum Direction as :
    /// {type:STRING, format:enum, enum:["EAST", NORTH", "SOUTH", "WEST"]}
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Possible values of the field.
    /// This field can be used to restrict a value to a fixed set of values.
    /// To mark a field as an enum, set `format` to `enum` and provide the list of
    /// possible values in `enum`.
    /// For example:
    /// 1. To define directions:
    /// `{type:STRING, format:enum, enum:["EAST", "NORTH", "SOUTH", "WEST"]}`
    /// 2. To define apartment numbers:
    /// `{type:INTEGER, format:enum, enum:["101", "201", "301"]}`
    package let `enum`: [String]?
    
    /// Optional. Schema of the elements of Type.ARRAY.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Schema of the elements of Type.ARRAY.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. If type is `ARRAY`, `items` specifies the schema of elements in the array.
    package let items: Schema?
    
    /// Optional. Maximum number of the elements for Type.ARRAY.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Maximum number of the elements for Type.ARRAY.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. If type is `ARRAY`, `max_items` specifies the maximum number of items in an
    /// array.
    package let maxItems: String?
    
    /// Optional. Minimum number of the elements for Type.ARRAY.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Minimum number of the elements for Type.ARRAY.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. If type is `ARRAY`, `min_items` specifies the minimum number of items in an
    /// array.
    package let minItems: String?
    
    /// Optional. Properties of Type.OBJECT.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Properties of Type.OBJECT.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. If type is `OBJECT`, `properties` is a map of property names to schema
    /// definitions for each property of the object.
    package let properties: [String: Schema]?
    
    /// Optional. Required properties of Type.OBJECT.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Required properties of Type.OBJECT.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. If type is `OBJECT`, `required` lists the names of properties that must be
    /// present.
    package let required: [String]?
    
    /// Optional. Minimum number of the properties for Type.OBJECT.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Minimum number of the properties for Type.OBJECT.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. If type is `OBJECT`, `min_properties` specifies the minimum number of
    /// properties that can be provided.
    package let minProperties: String?
    
    /// Optional. Maximum number of the properties for Type.OBJECT.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Maximum number of the properties for Type.OBJECT.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. If type is `OBJECT`, `max_properties` specifies the maximum number of
    /// properties that can be provided.
    package let maxProperties: String?
    
    /// Optional. SCHEMA FIELDS FOR TYPE INTEGER and NUMBER
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. SCHEMA FIELDS FOR TYPE INTEGER and NUMBER
    /// Minimum value of the Type.INTEGER and Type.NUMBER
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. If type is `INTEGER` or `NUMBER`, `minimum` specifies the minimum allowed
    /// value.
    package let minimum: Double?
    
    /// Optional. Maximum value of the Type.INTEGER and Type.NUMBER
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Maximum value of the Type.INTEGER and Type.NUMBER
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. If type is `INTEGER` or `NUMBER`, `maximum` specifies the maximum allowed
    /// value.
    package let maximum: Double?
    
    /// Optional. SCHEMA FIELDS FOR TYPE STRING
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. SCHEMA FIELDS FOR TYPE STRING
    /// Minimum length of the Type.STRING
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. If type is `STRING`, `min_length` specifies the minimum length of the
    /// string.
    package let minLength: String?
    
    /// Optional. Maximum length of the Type.STRING
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Maximum length of the Type.STRING
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. If type is `STRING`, `max_length` specifies the maximum length of the
    /// string.
    package let maxLength: String?
    
    /// Optional. Pattern of the Type.STRING to restrict a string to a regular expression.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Pattern of the Type.STRING to restrict a string to a regular expression.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. If type is `STRING`, `pattern` specifies a regular expression that the
    /// string must match.
    package let pattern: String?
    
    /// Optional. Example of the object. Will only populated when the object is the root.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Example of the object. Will only populated when the object is the root.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Example of an instance of this schema.
    package let example: JSONValue?
    
    /// Optional. The value should be validated against any (one or more) of the subschemas
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The value should be validated against any (one or more) of the subschemas
    /// in the list.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The instance must be valid against any (one or more) of the subschemas
    /// listed in `any_of`.
    package let anyOf: [Schema]?
    
    /// Optional. The order of the properties.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The order of the properties.
    /// Not a standard field in open api spec. Used to determine the order of the
    /// properties in the response.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Order of properties displayed or used where order matters.
    /// This is not a standard field in OpenAPI specification, but can be used to
    /// control the order of properties.
    package let propertyOrdering: [String]?
    
    /// Optional. Default value of the field. Per JSON Schema, this field is intended for
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Default value of the field. Per JSON Schema, this field is intended for
    /// documentation generators and doesn't affect validation. Thus it's included
    /// here and ignored so that developers who send schemas with a `default` field
    /// don't get unknown-field errors.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Default value to use if the field is not specified.
    package let `default`: JSONValue?
    
    /// Optional. If `type` is `OBJECT`, specifies how to handle properties not defined in
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. If `type` is `OBJECT`, specifies how to handle properties not defined in
    /// `properties`.
    /// If it is a boolean `false`, no additional properties are allowed.
    /// If it is a schema, additional properties are allowed if they conform to the
    /// schema.
    package let additionalProperties: JSONValue?
    
    /// Optional. Allows referencing another schema definition to use in place of this
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Allows referencing another schema definition to use in place of this
    /// schema. The value must be a valid reference to a schema in `defs`.
    /// 
    /// For example, the following schema defines a reference to a schema node
    /// named "Pet":
    /// 
    /// type: object
    /// properties:
    ///   pet:
    ///     ref: #/defs/Pet
    /// defs:
    ///   Pet:
    ///     type: object
    ///     properties:
    ///       name:
    ///         type: string
    /// 
    /// The value of the "pet" property is a reference to the schema node
    /// named "Pet".
    /// See details in
    /// https://json-schema.org/understanding-json-schema/structuring
    package let ref: String?
    
    /// Optional. `defs` provides a map of schema definitions that can be reused by `ref`
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. `defs` provides a map of schema definitions that can be reused by `ref`
    /// elsewhere in the schema.
    /// Only allowed at root level of the schema.
    package let defs: [String: Schema]?
    

    /// Creates a new `Schema`.
    ///
    /// - Parameters:
    ///   - type: Required. Data type. (behavior varies by backend). For more details, see ``type``.
    ///   - format: Optional. The format of the data. Any value is allowed, but most do not trigger any (behavior varies by backend). For more details, see ``format``.
    ///   - title: Optional. The title of the schema. (behavior varies by backend). For more details, see ``title``.
    ///   - description: Optional. A brief description of the parameter. This could contain examples of use. (behavior varies by backend). For more details, see ``description``.
    ///   - nullable: Optional. Indicates if the value may be null. (behavior varies by backend). For more details, see ``nullable``.
    ///   - `enum`: Optional. Possible values of the element of Type.STRING with enum format. (behavior varies by backend). For more details, see ```enum```.
    ///   - items: Optional. Schema of the elements of Type.ARRAY. (behavior varies by backend). For more details, see ``items``.
    ///   - maxItems: Optional. Maximum number of the elements for Type.ARRAY. (behavior varies by backend). For more details, see ``maxItems``.
    ///   - minItems: Optional. Minimum number of the elements for Type.ARRAY. (behavior varies by backend). For more details, see ``minItems``.
    ///   - properties: Optional. Properties of Type.OBJECT. (behavior varies by backend). For more details, see ``properties``.
    ///   - required: Optional. Required properties of Type.OBJECT. (behavior varies by backend). For more details, see ``required``.
    ///   - minProperties: Optional. Minimum number of the properties for Type.OBJECT. (behavior varies by backend). For more details, see ``minProperties``.
    ///   - maxProperties: Optional. Maximum number of the properties for Type.OBJECT. (behavior varies by backend). For more details, see ``maxProperties``.
    ///   - minimum: Optional. SCHEMA FIELDS FOR TYPE INTEGER and NUMBER (behavior varies by backend). For more details, see ``minimum``.
    ///   - maximum: Optional. Maximum value of the Type.INTEGER and Type.NUMBER (behavior varies by backend). For more details, see ``maximum``.
    ///   - minLength: Optional. SCHEMA FIELDS FOR TYPE STRING (behavior varies by backend). For more details, see ``minLength``.
    ///   - maxLength: Optional. Maximum length of the Type.STRING (behavior varies by backend). For more details, see ``maxLength``.
    ///   - pattern: Optional. Pattern of the Type.STRING to restrict a string to a regular expression. (behavior varies by backend). For more details, see ``pattern``.
    ///   - example: Optional. Example of the object. Will only populated when the object is the root. (behavior varies by backend). For more details, see ``example``.
    ///   - anyOf: Optional. The value should be validated against any (one or more) of the subschemas (behavior varies by backend). For more details, see ``anyOf``.
    ///   - propertyOrdering: Optional. The order of the properties. (behavior varies by backend). For more details, see ``propertyOrdering``.
    ///   - `default`: Optional. Default value of the field. Per JSON Schema, this field is intended for (behavior varies by backend). For more details, see ```default```.
    ///   - additionalProperties: Optional. If `type` is `OBJECT`, specifies how to handle properties not defined in (Gemini Enterprise Agent Platform only). For more details, see ``additionalProperties``.
    ///   - ref: Optional. Allows referencing another schema definition to use in place of this (Gemini Enterprise Agent Platform only). For more details, see ``ref``.
    ///   - defs: Optional. `defs` provides a map of schema definitions that can be reused by `ref` (Gemini Enterprise Agent Platform only). For more details, see ``defs``.
    package init(
      type: DataType,
      format: String? = nil,
      title: String? = nil,
      description: String? = nil,
      nullable: Bool? = nil,
      `enum`: [String]? = nil,
      items: Schema? = nil,
      maxItems: String? = nil,
      minItems: String? = nil,
      properties: [String: Schema]? = nil,
      required: [String]? = nil,
      minProperties: String? = nil,
      maxProperties: String? = nil,
      minimum: Double? = nil,
      maximum: Double? = nil,
      minLength: String? = nil,
      maxLength: String? = nil,
      pattern: String? = nil,
      example: JSONValue? = nil,
      anyOf: [Schema]? = nil,
      propertyOrdering: [String]? = nil,
      `default`: JSONValue? = nil,
      additionalProperties: JSONValue? = nil,
      ref: String? = nil,
      defs: [String: Schema]? = nil
    ) {
      self.type = type
      self.format = format
      self.title = title
      self.description = description
      self.nullable = nullable
      self.`enum` = `enum`
      self.items = items
      self.maxItems = maxItems
      self.minItems = minItems
      self.properties = properties
      self.required = required
      self.minProperties = minProperties
      self.maxProperties = maxProperties
      self.minimum = minimum
      self.maximum = maximum
      self.minLength = minLength
      self.maxLength = maxLength
      self.pattern = pattern
      self.example = example
      self.anyOf = anyOf
      self.propertyOrdering = propertyOrdering
      self.`default` = `default`
      self.additionalProperties = additionalProperties
      self.ref = ref
      self.defs = defs
    }
    enum CodingKeys: String, CodingKey {
      case type = "type"
      case format = "format"
      case title = "title"
      case description = "description"
      case nullable = "nullable"
      case `enum` = "enum"
      case items = "items"
      case maxItems = "maxItems"
      case minItems = "minItems"
      case properties = "properties"
      case required = "required"
      case minProperties = "minProperties"
      case maxProperties = "maxProperties"
      case minimum = "minimum"
      case maximum = "maximum"
      case minLength = "minLength"
      case maxLength = "maxLength"
      case pattern = "pattern"
      case example = "example"
      case anyOf = "anyOf"
      case propertyOrdering = "propertyOrdering"
      case `default` = "default"
      case additionalProperties = "additionalProperties"
      case ref = "ref"
      case defs = "defs"
    }
  }
}

// MARK: - Equatable & Hashable Conformance

extension GeminiDataModels.Schema: Equatable, Hashable {
  package static func == (lhs: GeminiDataModels.Schema, rhs: GeminiDataModels.Schema) -> Bool {
    return
      lhs.type == rhs.type &&
      lhs.format == rhs.format &&
      lhs.title == rhs.title &&
      lhs.description == rhs.description &&
      lhs.nullable == rhs.nullable &&
      lhs.`enum` == rhs.`enum` &&
      lhs.items == rhs.items &&
      lhs.maxItems == rhs.maxItems &&
      lhs.minItems == rhs.minItems &&
      lhs.properties == rhs.properties &&
      lhs.required == rhs.required &&
      lhs.minProperties == rhs.minProperties &&
      lhs.maxProperties == rhs.maxProperties &&
      lhs.minimum == rhs.minimum &&
      lhs.maximum == rhs.maximum &&
      lhs.minLength == rhs.minLength &&
      lhs.maxLength == rhs.maxLength &&
      lhs.pattern == rhs.pattern &&
      lhs.example == rhs.example &&
      lhs.anyOf == rhs.anyOf &&
      lhs.propertyOrdering == rhs.propertyOrdering &&
      lhs.`default` == rhs.`default` &&
      lhs.additionalProperties == rhs.additionalProperties &&
      lhs.ref == rhs.ref &&
      lhs.defs == rhs.defs
  }

  package func hash(into hasher: inout Hasher) {
    hasher.combine(type)
    hasher.combine(format)
    hasher.combine(title)
    hasher.combine(description)
    hasher.combine(nullable)
    hasher.combine(`enum`)
    hasher.combine(items)
    hasher.combine(maxItems)
    hasher.combine(minItems)
    hasher.combine(properties)
    hasher.combine(required)
    hasher.combine(minProperties)
    hasher.combine(maxProperties)
    hasher.combine(minimum)
    hasher.combine(maximum)
    hasher.combine(minLength)
    hasher.combine(maxLength)
    hasher.combine(pattern)
    hasher.combine(example)
    hasher.combine(anyOf)
    hasher.combine(propertyOrdering)
    hasher.combine(`default`)
    hasher.combine(additionalProperties)
    hasher.combine(ref)
    hasher.combine(defs)
  }
}