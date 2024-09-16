// Copyright 2024 Google LLC
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

/// A `Schema` object allows the definition of input and output data types.
///
/// These types can be objects, but also primitives and arrays. Represents a select subset of an
/// [OpenAPI 3.0 schema object](https://spec.openapis.org/oas/v3.0.3#schema).
public class Schema {
  public enum StringFormat {
    case custom(String)
  }

  public enum IntegerFormat {
    case int32
    case int64
    case custom(String)
  }

  /// The data type.
  let type: DataType

  /// The format of the data.
  let format: String?

  /// A brief description of the parameter.
  let description: String?

  /// Indicates if the value may be null.
  let nullable: Bool?

  /// Possible values of the element of type ``DataType/string`` with "enum" format.
  let enumValues: [String]?

  /// Schema of the elements of type ``DataType/array``.
  let items: Schema?

  /// Properties of type ``DataType/object``.
  let properties: [String: Schema]?

  /// Required properties of type ``DataType/object``.
  let requiredProperties: [String]?

  /// Constructs a new `Schema`.
  ///
  /// - Parameters:
  ///   - type: The data type.
  ///   - format: The format of the data; used only for primitive datatypes.
  ///     Supported formats:
  ///     - ``DataType/integer``: int32, int64
  ///     - ``DataType/number``: float, double
  ///     - ``DataType/string``: enum
  ///   - description: A brief description of the parameter; may be formatted as Markdown.
  ///   - nullable: Indicates if the value may be null.
  ///   - enumValues: Possible values of the element of type ``DataType/string`` with "enum" format.
  ///     For example, an enum `Direction` may be defined as `["EAST", NORTH", "SOUTH", "WEST"]`.
  ///   - items: Schema of the elements of type ``DataType/array``.
  ///   - properties: Properties of type ``DataType/object``.
  ///   - requiredProperties: Required properties of type ``DataType/object``.
  @available(*, deprecated, message: """
  Use static methods `string(description:format:nullable:)`, `number(description:format:nullable:)`,
  etc., instead.
  """)
  public convenience init(type: DataType, format: String? = nil, description: String? = nil,
                          nullable: Bool? = nil,
                          enumValues: [String]? = nil, items: Schema? = nil,
                          properties: [String: Schema]? = nil,
                          requiredProperties: [String]? = nil) {
    self.init(
      type: type,
      format: format,
      description: description,
      nullable: nullable ?? false,
      enumValues: enumValues,
      items: items,
      properties: properties,
      requiredProperties: requiredProperties
    )
  }

  required init(type: DataType, format: String? = nil, description: String? = nil,
                nullable: Bool = false,
                enumValues: [String]? = nil, items: Schema? = nil,
                properties: [String: Schema]? = nil,
                requiredProperties: [String]? = nil) {
    self.type = type
    self.format = format
    self.description = description
    self.nullable = nullable
    self.enumValues = enumValues
    self.items = items
    self.properties = properties
    self.requiredProperties = requiredProperties
  }

  public static func string(description: String? = nil, nullable: Bool = false,
                            format: StringFormat? = nil) -> Schema {
    return self.init(
      type: .string,
      format: format?.rawValue, description: description,
      nullable: nullable
    )
  }

  public static func enumeration(values: [String], description: String?, nullable: Bool) -> Schema {
    return self.init(
      type: .string,
      format: "enum", description: description,
      nullable: nullable,
      enumValues: values
    )
  }

  public static func double(description: String? = nil, nullable: Bool = false) -> Schema {
    return self.init(
      type: .number,
      format: "double",
      description: description,
      nullable: nullable
    )
  }

  public static func float(description: String? = nil, nullable: Bool = false) -> Schema {
    return self.init(
      type: .number,
      format: "float",
      description: description,
      nullable: nullable
    )
  }

  public static func integer(description: String? = nil, nullable: Bool = false,
                             format: IntegerFormat? = nil) -> Schema {
    return self.init(
      type: .integer,
      format: format?.rawValue,
      description: description,
      nullable: nullable
    )
  }

  public static func boolean(description: String? = nil, nullable: Bool = false) -> Schema {
    return self.init(type: .boolean, description: description, nullable: nullable)
  }

  public static func array(items: Schema, description: String? = nil, nullable: Bool = false) -> Schema {
    return self.init(type: .array, description: description, nullable: nullable, items: items)
  }

  public static func object(description: String? = nil, nullable: Bool = false,
                            properties: [String: Schema],
                            optionalProperties: [String] = []) -> Schema {
    var requiredProperties = Set(properties.keys)
    for optionalProperty in optionalProperties {
      guard properties.keys.contains(optionalProperty) else {
        fatalError("Optional property \"\(optionalProperty)\" not defined in object properties.")
      }
      requiredProperties.remove(optionalProperty)
    }

    return self.init(
      type: .object,
      description: description,
      nullable: nullable,
      properties: properties,
      requiredProperties: requiredProperties.sorted()
    )
  }
}

/// A data type.
///
/// Contains the set of OpenAPI [data types](https://spec.openapis.org/oas/v3.0.3#data-types).
public enum DataType: String {
  /// A `String` type.
  case string = "STRING"

  /// A floating-point number type.
  case number = "NUMBER"

  /// An integer type.
  case integer = "INTEGER"

  /// A boolean type.
  case boolean = "BOOLEAN"

  /// An array type.
  case array = "ARRAY"

  /// An object type.
  case object = "OBJECT"
}

// MARK: - Codable Conformance

extension Schema: Encodable {
  enum CodingKeys: String, CodingKey {
    case type
    case format
    case description
    case nullable
    case enumValues = "enum"
    case items
    case properties
    case requiredProperties = "required"
  }
}

extension DataType: Encodable {}

// MARK: - RawRepresentable Conformance

extension Schema.IntegerFormat: RawRepresentable {
  public init?(rawValue: String) {
    switch rawValue {
    case "int32":
      self = .int32
    case "int64":
      self = .int64
    default:
      self = .custom(rawValue)
    }
  }

  public var rawValue: String {
    switch self {
    case .int32:
      return "int32"
    case .int64:
      return "int64"
    case let .custom(format):
      return format
    }
  }
}

extension Schema.StringFormat: RawRepresentable {
  public init?(rawValue: String) {
    switch rawValue {
    default:
      self = .custom(rawValue)
    }
  }

  public var rawValue: String {
    switch self {
    case let .custom(format):
      return format
    }
  }
}
