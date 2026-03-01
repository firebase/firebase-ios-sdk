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

struct SchemaConfig {
  var additionalPropertiesAsSchema: Bool = true
  var propertyOrderingKey: String?

  init(additionalPropertiesAsSchema: Bool = true, propertyOrderingKey: String? = nil) {
    self.additionalPropertiesAsSchema = additionalPropertiesAsSchema
    self.propertyOrderingKey = propertyOrderingKey
  }
}

/// Generates a JSON Schema dictionary for a given Decodable type.
/// - Parameter type: The type to reflect (e.g., User.self).
/// - Returns: A JSONSchema struct describing the type.
func generateSchema<T: Decodable>(for type: T.Type,
                                  config: SchemaConfig = SchemaConfig())
  -> FirebaseGenerationSchema {
  let rootTitle = String(describing: type)

  // 1. Resolve Constraints
  var constraintMap: [String: SchemaConstraint] = [:]
  if let customizable = T.self as? SchemaConstraintsProvider.Type {
    for (key, constraint) in customizable.schemaConstraints {
      if let stringKey = key as? String {
        constraintMap[stringKey] = constraint
      } else if let codingKey = key.base as? CodingKey {
        constraintMap[codingKey.stringValue] = constraint
      } else {
        assertionFailure("""
        Constraint key '\(key)' in \(rootTitle) is not a String or CodingKey.
        """)
      }
    }
  }

  // 2. Create Decoder with constraints
  let decoder = SchemaDecoder(config: config, title: rootTitle, constraints: constraintMap)

  // We attempt to decode the type. The decoder will "spy" on the structure
  // and build the schema internally.
  // We ignore errors because the "dummy" data might fail specific validation logic in init.
  try? _ = T(from: decoder)

  // 3. --- SAFETY CHECK ---
  // Calculate which keys were defined in constraints but NEVER visited by the decoder.
  // This detects typos or renamed properties.
  let definedKeys = Set(constraintMap.keys)
  let visitedKeys = decoder.visitedKeys
  let unusedKeys = definedKeys.subtracting(visitedKeys)

  assert(unusedKeys.isEmpty, """
  The following schema constraints for type '\(rootTitle)' were unused: \(unusedKeys). This \
  usually means there is a typo in the constraint key, or the property was not decoded.
  """)

  var schema = decoder.schema
  // Ensure root title is set (it should be via SchemaDecoder, but just in case)
  if schema.title == nil {
    schema.title = rootTitle
  }
  return schema
}

// MARK: - Schema Models

enum SchemaOrBool: Encodable {
  case schema(FirebaseGenerationSchema)
  case bool(Bool)

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case let .schema(s): try container.encode(s)
    case let .bool(b): try container.encode(b)
    }
  }
}

struct FirebaseGenerationSchema: Encodable, CustomStringConvertible {
  var title: String?
  var type: String = "object"
  var properties: [String: FirebaseGenerationSchema]? = nil
  var required: [String]? = nil
  var items: Box<FirebaseGenerationSchema>? // For arrays
  var additionalProperties: Box<SchemaOrBool>? // For dictionaries

  // Ordering support
  var propertyOrder: [String]? = nil
  var propertyOrderingKey: String? = nil

  // Constraints
  var minimum: Double?
  var maximum: Double?
  var pattern: String?
  var minLength: Int?
  var maxLength: Int?
  var minItems: Int?
  var maxItems: Int?
  var uniqueItems: Bool?
  var descriptionText: String? // 'description' is reserved in CustomStringConvertible

  // Helper helper to handle recursive struct definitions in structs
  class Box<T>: Encodable, CustomStringConvertible {
    let value: T
    init(_ value: T) { self.value = value }

    func encode(to encoder: Encoder) throws {
      if let v = value as? Encodable {
        try v.encode(to: encoder)
      }
    }

    var description: String { return "\(value)" }
  }

  private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: DynamicCodingKey.self)
    if let t = title {
      try container.encode(t, forKey: DynamicCodingKey(stringValue: "title")!)
    }
    try container.encode(type, forKey: DynamicCodingKey(stringValue: "type")!)

    if let p = properties {
      try container.encode(p, forKey: DynamicCodingKey(stringValue: "properties")!)
    }
    if let r = required {
      try container.encode(r, forKey: DynamicCodingKey(stringValue: "required")!)
    }
    if let i = items {
      try container.encode(i, forKey: DynamicCodingKey(stringValue: "items")!)
    }
    if let ap = additionalProperties {
      try container.encode(ap, forKey: DynamicCodingKey(stringValue: "additionalProperties")!)
    }

    if let order = propertyOrder, let key = propertyOrderingKey {
      try container.encode(order, forKey: DynamicCodingKey(stringValue: key)!)
    }

    // Constraints
    if let v = minimum { try container.encode(v, forKey: DynamicCodingKey(stringValue: "minimum")!)
    }
    if let v = maximum { try container.encode(v, forKey: DynamicCodingKey(stringValue: "maximum")!)
    }
    if let v = pattern { try container.encode(v, forKey: DynamicCodingKey(stringValue: "pattern")!)
    }
    if let v = minLength { try container.encode(
      v,
      forKey: DynamicCodingKey(stringValue: "minLength")!
    ) }
    if let v = maxLength { try container.encode(
      v,
      forKey: DynamicCodingKey(stringValue: "maxLength")!
    ) }
    if let v = minItems {
      try container.encode(v, forKey: DynamicCodingKey(stringValue: "minItems")!)
    }
    if let v = maxItems {
      try container.encode(v, forKey: DynamicCodingKey(stringValue: "maxItems")!)
    }
    if let v = uniqueItems { try container.encode(
      v,
      forKey: DynamicCodingKey(stringValue: "uniqueItems")!
    ) }
    if let v = descriptionText { try container.encode(
      v,
      forKey: DynamicCodingKey(stringValue: "description")!
    ) }
  }

  public var description: String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(self) else { return "{}" }
    return String(data: data, encoding: .utf8) ?? "{}"
  }
}

// MARK: - The Spy Decoder

private class SchemaNode {
  var title: String?
  var type: String = "object"
  var properties: [String: SchemaNode] = [:]
  var propertiesOrder: [String] = []
  var required: [String] = []
  var items: SchemaNode?
  var additionalProperties: SchemaNode?

  // Constraints applied to this node
  var constraints: SchemaConstraint?

  func toSchema(config: SchemaConfig) -> FirebaseGenerationSchema {
    var s = FirebaseGenerationSchema()
    s.type = type
    s.title = title

    // Apply constraints
    if let c = constraints {
      // Validation: Check if constraints match the type (Debug Only)
      let isNumeric = (type == "integer" || type == "number")
      let isString = (type == "string")
      let isArray = (type == "array")

      assert(isNumeric || (c.minimum == nil && c.maximum == nil),
             "[SchemaBuilder] Numeric constraints (min/max) applied to non-numeric type '\(type)' for property '\(title ?? "?")'.")

      assert(isString || (c.pattern == nil && c.minLength == nil && c.maxLength == nil),
             "[SchemaBuilder] String constraints (pattern/length) applied to non-string type '\(type)' for property '\(title ?? "?")'.")

      assert(isArray || (c.minItems == nil && c.maxItems == nil && c.uniqueItems == nil),
             "[SchemaBuilder] Array constraints (items) applied to non-array type '\(type)' for property '\(title ?? "?")'.")

      s.minimum = c.minimum
      s.maximum = c.maximum
      s.pattern = c.pattern
      s.minLength = c.minLength
      s.maxLength = c.maxLength
      s.minItems = c.minItems
      s.maxItems = c.maxItems
      s.uniqueItems = c.uniqueItems
      s.descriptionText = c.description
    }

    if type == "object" {
      var props: [String: FirebaseGenerationSchema] = [:]
      for (k, v) in properties {
        props[k] = v.toSchema(config: config)
      }
      s.properties = props

      // Deduplicate required fields
      var seen = Set<String>()
      var uniqueRequired: [String] = []
      for r in required {
        if !seen.contains(r) {
          seen.insert(r)
          uniqueRequired.append(r)
        }
      }
      s.required = uniqueRequired

      if let ap = additionalProperties {
        if config.additionalPropertiesAsSchema {
          s.additionalProperties = FirebaseGenerationSchema
            .Box(.schema(ap.toSchema(config: config)))
        } else {
          s.additionalProperties = FirebaseGenerationSchema.Box(.bool(true))
        }
      } else {
        // Default to additionalProperties: false for structs (closed schema)
        s.additionalProperties = FirebaseGenerationSchema.Box(.bool(false))
      }

      // Handle ordering
      if let key = config.propertyOrderingKey {
        // Deduplicate order
        var seen = Set<String>()
        var uniqueOrder: [String] = []
        for r in propertiesOrder {
          if !seen.contains(r) {
            seen.insert(r)
            uniqueOrder.append(r)
          }
        }
        s.propertyOrder = uniqueOrder
        s.propertyOrderingKey = key
      }
    }

    if let i = items {
      s.items = FirebaseGenerationSchema.Box(i.toSchema(config: config))
    }
    return s
  }
}

private class SchemaDecoder: Decoder {
  var codingPath: [CodingKey] = []
  var userInfo: [CodingUserInfoKey: Any] = [:]

  let node: SchemaNode
  let config: SchemaConfig
  let title: String?

  // Constraints passed down to containers
  let constraints: [String: SchemaConstraint]

  // Track visited keys to detect unused constraints (typos)
  var visitedKeys: Set<String> = []

  init(node: SchemaNode = SchemaNode(),
       config: SchemaConfig = SchemaConfig(),
       title: String? = nil,
       constraints: [String: SchemaConstraint] = [:]) {
    self.node = node
    self.config = config
    self.title = title
    self.constraints = constraints

    if let t = title {
      node.title = t
    }
  }

  // This is the "Result" we are building
  var schema: FirebaseGenerationSchema { return node.toSchema(config: config) }

  func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>
    where Key: CodingKey {
    let container = SchemaKeyedContainer<Key>(decoder: self)
    return KeyedDecodingContainer(container)
  }

  func unkeyedContainer() throws -> UnkeyedDecodingContainer {
    return SchemaUnkeyedContainer(decoder: self)
  }

  func singleValueContainer() throws -> SingleValueDecodingContainer {
    return SchemaSingleValueContainer(decoder: self)
  }
}

// MARK: - Helper for Dummy Values

private func customTitle<T>(for type: T.Type) -> String? {
  let name = String(describing: type)
  // Filter generics and collections
  if name.contains("<") || name.contains("[") || name.contains("Dictionary") || name
    .contains("Array") || name.contains("Optional") {
    return nil
  }
  // Filter primitives and common types
  let ignored = [
    "String",
    "Int",
    "Double",
    "Bool",
    "Float",
    "UUID",
    "URL",
    "Date",
    "Data",
    "Decimal",
  ]
  if ignored.contains(name) || name.hasPrefix("Int") || name.hasPrefix("UInt") {
    return nil
  }
  return name
}

private func makeDummy<T: Decodable>(type: T.Type, decoder: SchemaDecoder) throws -> T {
  if type == Bool.self { return false as! T }
  if type == String.self { return "" as! T }
  if type == Double.self { return 0.0 as! T }
  if type == Float.self { return 0.0 as! T }
  if type == Int.self { return 0 as! T }
  if type == Int8.self { return 0 as! T }
  if type == Int16.self { return 0 as! T }
  if type == Int32.self { return 0 as! T }
  if type == Int64.self { return 0 as! T }
  if type == UInt.self { return 0 as! T }
  if type == UInt8.self { return 0 as! T }
  if type == UInt16.self { return 0 as! T }
  if type == UInt32.self { return 0 as! T }
  if type == UInt64.self { return 0 as! T }

  // Common Foundation types that validate inputs
  if type == UUID.self { return UUID() as! T }
  if type == URL.self { return URL(string: "http://example.com")! as! T }
  if type == Date.self { return Date() as! T }

  // Fallback to standard decoding (recurse)
  return try T(from: decoder)
}

// MARK: - Keyed Container (The Object Handler)

private class SchemaKeyedContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
  typealias Key = K
  var codingPath: [CodingKey] = []
  var allKeys: [K] = []
  let decoder: SchemaDecoder

  init(decoder: SchemaDecoder) {
    self.decoder = decoder
    // Try to inject a dummy key to detect dictionaries.
    // Structs with Enum keys will usually fail this init.
    // Dictionaries use a wrapper that succeeds.
    if let dummy = K(stringValue: "schema_spy_key") {
      allKeys = [dummy]
    }
  }

  func contains(_ key: K) -> Bool { return true }

  // Helper to register a field
  private func register(key: K, type: String, isOptional: Bool = false) {
    let node = SchemaNode()
    node.type = type

    // --- Constraint Handling ---
    decoder.visitedKeys.insert(key.stringValue)
    if let constraint = decoder.constraints[key.stringValue] {
      node.constraints = constraint
    }
    // ---------------------------

    if key.stringValue == "schema_spy_key" {
      decoder.node.additionalProperties = node
    } else {
      decoder.node.properties[key.stringValue] = node
      if !isOptional {
        decoder.node.required.append(key.stringValue)
      }
      decoder.node.propertiesOrder.append(key.stringValue)
    }
  }

  // --- Primitive Types ---

  func decodeNil(forKey key: K) throws -> Bool { return false }

  func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
    register(key: key, type: "boolean")
    return false
  }

  func decode(_ type: String.Type, forKey key: K) throws -> String {
    register(key: key, type: "string")
    return ""
  }

  func decode(_ type: Double.Type, forKey key: K) throws -> Double {
    register(key: key, type: "number")
    return 0.0
  }

  func decode(_ type: Float.Type, forKey key: K) throws -> Float {
    register(key: key, type: "number")
    return 0.0
  }

  func decode(_ type: Int.Type, forKey key: K) throws -> Int {
    register(key: key, type: "integer")
    return 0
  }

  // Add other Int types (Int8, Int16, etc.) similarly...
  func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 { register(
    key: key,
    type: "integer"
  ); return 0 }
  func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 { register(
    key: key,
    type: "integer"
  ); return 0 }
  func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 { register(
    key: key,
    type: "integer"
  ); return 0 }
  func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 { register(
    key: key,
    type: "integer"
  ); return 0 }
  func decode(_ type: UInt.Type, forKey key: K) throws -> UInt { register(
    key: key,
    type: "integer"
  ); return 0 }

  // --- Complex / Nested Types ---

  func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T: Decodable {
    // 1. Create a child node
    let childNode = SchemaNode()

    // --- Constraint Handling ---
    decoder.visitedKeys.insert(key.stringValue)
    if let constraint = decoder.constraints[key.stringValue] {
      childNode.constraints = constraint
    }
    // ---------------------------

    if key.stringValue == "schema_spy_key" {
      decoder.node.additionalProperties = childNode
    } else {
      decoder.node.properties[key.stringValue] = childNode
      decoder.node.required.append(key.stringValue)
      decoder.node.propertiesOrder.append(key.stringValue)
    }

    // Explicit support for primitives and Foundation types
    if type == String.self { childNode.type = "string" }
    else if type == Int.self { childNode.type = "integer" }
    else if type == Bool.self { childNode.type = "boolean" }
    else if type == Double.self { childNode.type = "number" }
    else if type == UUID.self {
      childNode.type = "string"
      return UUID() as! T
    } else if type == URL.self {
      childNode.type = "string"
      return URL(string: "https://example.com")! as! T
    } else if type == Date.self {
      childNode.type = "string"
      return Date() as! T
    }

    // 2. Create subDecoder pointing to childNode
    var subTitle = (decoder.title != nil ? decoder.title! + "." : "") + key.stringValue
    if let custom = customTitle(for: type) {
      subTitle = custom
    }
    let subDecoder = SchemaDecoder(node: childNode, config: decoder.config, title: subTitle)

    // 3. Spy & Return Dummy
    // We use makeDummy to handle UUIDs/URLs etc preventing aborts
    if let dummy = try? makeDummy(type: type, decoder: subDecoder) {
      return dummy
    }

    // Fallback: throw to exit this branch, but we already recorded the schema!
    throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Spying")
  }

  // --- Optionals ---
  // Decodable calls decodeIfPresent for optionals.

  func decodeIfPresent<T>(_ type: T.Type, forKey key: K) throws -> T? where T: Decodable {
    // It is optional, so we do NOT add it to `required`

    let childNode = SchemaNode()

    // --- Constraint Handling ---
    decoder.visitedKeys.insert(key.stringValue)
    if let constraint = decoder.constraints[key.stringValue] {
      childNode.constraints = constraint
    }
    // ---------------------------

    if key.stringValue == "schema_spy_key" {
      decoder.node.additionalProperties = childNode
    } else {
      decoder.node.properties[key.stringValue] = childNode
      decoder.node.propertiesOrder.append(key.stringValue)
    }

    if type == UUID.self || type == URL.self || type == Date.self {
      childNode.type = "string"
      return nil
    }

    var subTitle = (decoder.title != nil ? decoder.title! + "." : "") + key.stringValue
    if let custom = customTitle(for: type) {
      subTitle = custom
    }
    let subDecoder = SchemaDecoder(node: childNode, config: decoder.config, title: subTitle)
    let _ = try? makeDummy(type: type, decoder: subDecoder)

    // If it was a primitive (like String?), the subDecoder might not have set type if not visited
    // We need to check if T is a primitive type to correct the schema type.
    if type == String.self { childNode.type = "string" }
    else if type == Int.self { childNode.type = "integer" }
    else if type == Bool.self { childNode.type = "boolean" }
    else if type == Double.self { childNode.type = "number" }
    else if type == UUID.self { childNode.type = "string" } // Heuristic
    else if type == URL.self { childNode.type = "string" }
    else if type == Date.self { childNode.type = "string" }

    return nil // Return nil so the struct gets `nil` for this property
  }

  // Explicit overloads for primitives to ensure they hit decodeIfPresent and not decode
  func decodeIfPresent(_ type: Bool.Type, forKey key: K) throws -> Bool? {
    register(key: key, type: "boolean", isOptional: true)
    return nil
  }

  func decodeIfPresent(_ type: String.Type, forKey key: K) throws -> String? {
    register(key: key, type: "string", isOptional: true)
    return nil
  }

  func decodeIfPresent(_ type: Double.Type, forKey key: K) throws -> Double? {
    register(key: key, type: "number", isOptional: true)
    return nil
  }

  func decodeIfPresent(_ type: Float.Type, forKey key: K) throws -> Float? {
    register(key: key, type: "number", isOptional: true)
    return nil
  }

  func decodeIfPresent(_ type: Int.Type, forKey key: K) throws -> Int? {
    register(key: key, type: "integer", isOptional: true)
    return nil
  }

  func decodeIfPresent(_ type: Int8.Type, forKey key: K) throws -> Int8? { register(
    key: key,
    type: "integer",
    isOptional: true
  ); return nil }
  func decodeIfPresent(_ type: Int16.Type, forKey key: K) throws -> Int16? { register(
    key: key,
    type: "integer",
    isOptional: true
  ); return nil }
  func decodeIfPresent(_ type: Int32.Type, forKey key: K) throws -> Int32? { register(
    key: key,
    type: "integer",
    isOptional: true
  ); return nil }
  func decodeIfPresent(_ type: Int64.Type, forKey key: K) throws -> Int64? { register(
    key: key,
    type: "integer",
    isOptional: true
  ); return nil }
  func decodeIfPresent(_ type: UInt.Type, forKey key: K) throws -> UInt? { register(
    key: key,
    type: "integer",
    isOptional: true
  ); return nil }

  // --- Nested Containers ---

  func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type,
                                  forKey key: K) throws -> KeyedDecodingContainer<NestedKey>
    where NestedKey: CodingKey {
    let childNode = SchemaNode()
    childNode.type = "object"

    // --- Constraint Handling ---
    decoder.visitedKeys.insert(key.stringValue)
    if let constraint = decoder.constraints[key.stringValue] {
      childNode.constraints = constraint
    }
    // ---------------------------

    if key.stringValue == "schema_spy_key" {
      decoder.node.additionalProperties = childNode
    } else {
      decoder.node.properties[key.stringValue] = childNode
      decoder.node.required.append(key.stringValue)
      decoder.node.propertiesOrder.append(key.stringValue)
    }

    let subTitle = (decoder.title != nil ? decoder.title! + "." : "") + key.stringValue
    let subDecoder = SchemaDecoder(node: childNode, config: decoder.config, title: subTitle)
    let container = SchemaKeyedContainer<NestedKey>(decoder: subDecoder)
    return KeyedDecodingContainer(container)
  }

  func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
    let childNode = SchemaNode()
    childNode.type = "array"

    // --- Constraint Handling ---
    decoder.visitedKeys.insert(key.stringValue)
    if let constraint = decoder.constraints[key.stringValue] {
      childNode.constraints = constraint
    }
    // ---------------------------

    if key.stringValue == "schema_spy_key" {
      decoder.node.additionalProperties = childNode
    } else {
      decoder.node.properties[key.stringValue] = childNode
      decoder.node.required.append(key.stringValue)
      decoder.node.propertiesOrder.append(key.stringValue)
    }

    let subTitle = (decoder.title != nil ? decoder.title! + "." : "") + key.stringValue
    let subDecoder = SchemaDecoder(node: childNode, config: decoder.config, title: subTitle)
    return SchemaUnkeyedContainer(decoder: subDecoder)
  }

  func superDecoder() throws -> Decoder {
    return decoder
  }

  func superDecoder(forKey key: K) throws -> Decoder {
    let childNode = SchemaNode()

    // --- Constraint Handling ---
    decoder.visitedKeys.insert(key.stringValue)
    if let constraint = decoder.constraints[key.stringValue] {
      childNode.constraints = constraint
    }
    // ---------------------------

    if key.stringValue == "schema_spy_key" {
      decoder.node.additionalProperties = childNode
    } else {
      decoder.node.properties[key.stringValue] = childNode
      decoder.node.required.append(key.stringValue)
      decoder.node.propertiesOrder.append(key.stringValue)
    }
    let subTitle = (decoder.title != nil ? decoder.title! + "." : "") + key.stringValue
    return SchemaDecoder(node: childNode, config: decoder.config, title: subTitle)
  }
}

// MARK: - Unkeyed Container (The Array Handler)

private class SchemaUnkeyedContainer: UnkeyedDecodingContainer {
  var codingPath: [CodingKey] = []
  var count: Int? = 0
  var isAtEnd: Bool = false
  var currentIndex: Int = 0
  let decoder: SchemaDecoder

  init(decoder: SchemaDecoder) {
    self.decoder = decoder
    // When a type requests an unkeyed container, it is an Array (or Set).
    decoder.node.type = "array"
  }

  func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
    // We are inside an array (e.g., [String] or [User]).
    // We need to define the `items` property of the schema.

    let childNode = SchemaNode()

    // Check for Primitives explicitly to set simple types
    if type == String.self { childNode.type = "string" }
    else if type == Int.self { childNode.type = "integer" }
    else if type == Bool.self { childNode.type = "boolean" }
    else if type == Double.self { childNode.type = "number" }
    else if type == UUID.self {
      childNode.type = "string"
      decoder.node.items = childNode
      isAtEnd = true // Stop array iteration
      return UUID() as! T
    } else if type == URL.self {
      childNode.type = "string"
      decoder.node.items = childNode
      isAtEnd = true // Stop array iteration
      return URL(string: "https://example.com")! as! T
    } else if type == Date.self {
      childNode.type = "string"
      decoder.node.items = childNode
      isAtEnd = true // Stop array iteration
      return Date() as! T
    } else {
      // It's a complex object, recurse
      let subDecoder = SchemaDecoder(node: childNode, config: decoder.config)
      // Use makeDummy to try to get a value
      let _ = try? makeDummy(type: type, decoder: subDecoder)
    }

    decoder.node.items = childNode

    // IMPORTANT: We only want to decode ONE item to get the schema.
    // If we return a value, the Array init will ask for the next one.
    // We set isAtEnd to true so the Array init stops after this one.
    isAtEnd = true

    // Return a dummy value so Array init doesn't throw
    if let dummy = try? makeDummy(
      type: type,
      decoder: SchemaDecoder(node: SchemaNode(), config: decoder.config)
    ) {
      return dummy
    }

    throw DecodingError.dataCorruptedError(
      in: self,
      debugDescription: "Could not create dummy for array item"
    )
  }

  // Boilerplate for primitives in arrays
  func decodeNil() throws -> Bool { return false }

  func nestedContainer<NestedKey>(keyedBy type: NestedKey
    .Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
    let childNode = SchemaNode()
    childNode.type = "object"
    decoder.node.items = childNode

    let subDecoder = SchemaDecoder(node: childNode, config: decoder.config)
    let container = SchemaKeyedContainer<NestedKey>(decoder: subDecoder)
    return KeyedDecodingContainer(container)
  }

  func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
    let childNode = SchemaNode()
    childNode.type = "array"
    decoder.node.items = childNode

    let subDecoder = SchemaDecoder(node: childNode, config: decoder.config)
    return SchemaUnkeyedContainer(decoder: subDecoder)
  }

  func superDecoder() throws -> Decoder { return decoder }
}

// MARK: - Single Value Container (Enum / Primitive Wrapper Handler)

private class SchemaSingleValueContainer: SingleValueDecodingContainer {
  var codingPath: [CodingKey] = []
  let decoder: SchemaDecoder

  init(decoder: SchemaDecoder) {
    self.decoder = decoder
  }

  func decodeNil() -> Bool { return false }

  func decode(_ type: Bool.Type) throws -> Bool { decoder.node.type = "boolean"; return false }
  func decode(_ type: String.Type) throws -> String { decoder.node.type = "string"; return "" }
  func decode(_ type: Double.Type) throws -> Double { decoder.node.type = "number"; return 0.0 }
  func decode(_ type: Float.Type) throws -> Float { decoder.node.type = "number"; return 0.0 }
  func decode(_ type: Int.Type) throws -> Int { decoder.node.type = "integer"; return 0 }

  // Boilerplate Ints
  func decode(_ type: Int8.Type) throws -> Int8 { decoder.node.type = "integer"; return 0 }
  func decode(_ type: Int16.Type) throws -> Int16 { decoder.node.type = "integer"; return 0 }
  func decode(_ type: Int32.Type) throws -> Int32 { decoder.node.type = "integer"; return 0 }
  func decode(_ type: Int64.Type) throws -> Int64 { decoder.node.type = "integer"; return 0 }
  func decode(_ type: UInt.Type) throws -> UInt { decoder.node.type = "integer"; return 0 }

  func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
    // Recursion for single values (rare in standard JSON objects, used in enums)
    let _ = try? T(from: decoder)
    return try! T(from: decoder) // This will likely fail or recurse
  }
}
