# Schema Encoding Plan

This document outlines the plan to implement a `JSONSchema` to JSON encoder. The goal is to produce
a `JSONSchema.Internal` (Encodable) representation from a `JSONSchema` instance, handling recursive
types efficiently using `$def` and `$ref`.

## Objective

- Produce an `Encodable` representation of `JSONSchema` in JSON Schema format.
- Support recursive schema definitions.
- Use `$def` (definitions) and `$ref` for shared/recursive schemas.
- **Root Constraint**: Root schema is always encoded inline.
- **Nested Constraint**: Nested object/anyOf schemas with a `title` are encoded as definitions and
  referenced.
- **Optionality**: Swift `Optional` types result in the field being omitted from `required`. We do
  **not** use `nullable: true` or `null` values, as this saves tokens and is required for Apple
  Foundation Models.
- **Excluded Constraints**: We intentionally omit `pattern`, `minLength`, `maxLength`, and
  `uniqueItems` as they are not currently supported by the SDK API surface.

## Components

### 1. `SchemaEncoder`

A class or struct responsible for the encoding process. It will maintain the state of encoding
(definitions, visited types).

```swift
struct SchemaEncoder {
    enum Target {
        case gemini
        case apple
    }
    
    let target: Target
}
```

### 2. `JSONSchema.Internal` (Intermediate Type)

An intermediate `Codable` class that mirrors the JSON Schema structure. This allows us to use
`JSONEncoder` for the final transformation and keeps the logic type-safe.

```swift
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
    }
}
```

**State:**

- `definitions: [String: JSONSchema.Internal]`: Stores the encoded schema bodies for types that are
  referenced.
- `visitedTypes: Set<ObjectIdentifier>`: Tracks the types that have been successfully processed or
  are currently being processed as definitions.
- `codingPath: Set<ObjectIdentifier>`: Tracks the current traversal path to detect infinite
  recursion in inline (nil-title) schemas.

### 3. Properties of `JSONSchema`

The `JSONSchema` struct supports the following `Kind`s:

- `.string`: encoded as `{"type": "string"}` (plus guides)
- `.integer`: encoded as `{"type": "integer"}` (plus guides)
- `.double`: encoded as `{"type": "number"}` (plus guides)
- `.boolean`: encoded as `{"type": "boolean"}`
- `.array(item: Type)`: encoded as `{"type": "array", "items": ...}`
- `.object(properties: ...)`: encoded as `{"type": "object", "properties": ...}`
- `.anyOf(types: ...)`: encoded as `{"anyOf": [...]}`

The `typeIdentifier` property (ObjectIdentifier) is used to uniquely identify types.

## Algorithm

The encoding process involves a traversal of the schema tree.

### `encode(_ schema: JSONSchema) -> JSONSchema.Internal`

1. **Initialize** `definitions` = `[:]`, `visitedTypes` = `[]`.
2. **Register Root**: Add `schema.typeIdentifier` to `visitedTypes`.
3. **Process Root**: `let rootInternal = process(schema, isRoot: true)`.
   - Explicitly ensure `rootInternal.title` is set to `schema.title` to preserve metadata for
     top-level validators.
4. **Assemble**:
   - If `definitions` is not empty, set `rootInternal.defs = definitions`.
5. **Return** `rootInternal`.

### `process(_ schema: JSONSchema, isRoot: Bool) -> JSONSchema.Internal`

This function returns the `JSONSchema.Internal` representation of a schema.

1. **Check for Root Reference**:
   - If `!isRoot` AND `schema.typeIdentifier == rootIdentifier`:
     - Return `JSONSchema.Internal(ref: "#")`.

2. **Check for Definition Reference**:
   - If `!isRoot` AND `schema.title != nil`:
     - **Ref Hit**: If `visitedTypes` contains `schema.typeIdentifier`:
       - Return `JSONSchema.Internal(ref: "#/$defs/\(schema.title!)")`.
     - **New Definition**:
       - Add `schema.typeIdentifier` to `visitedTypes`.
       - Encode the body: `body = encodeBody(schema)`.
       - Store `body` in `definitions[schema.title!]`.
       - Return `JSONSchema.Internal(ref: "#/$defs/\(schema.title!)")`.

3. **Inline Encoding (Recursion Check)**:
   - If `isRoot` OR `schema.title == nil`:
     - **Cycle Detection**: If `codingPath` contains `schema.typeIdentifier`:
       - Throw `SchemaError.circularDependency`.
     - Push `schema.typeIdentifier` to `codingPath`.
     - Encode body: `body = encodeBody(schema)`.
     - Pop `schema.typeIdentifier` from `codingPath`.
     - Return `body`.

### `encodeBody(_ schema: JSONSchema) -> JSONSchema.Internal`

Encodes the specific details of the schema kind into an `JSONSchema.Internal` object.

- **General**:
  - `internal.title = schema.title` (if encoded inline)
  - `internal.description = schema.description`

- **String**:
  - `JSONSchema.Internal(type: .string)`
  - Apply `guides`.
    - Map `StringGuides.anyOf` to `internal.enumValues` (the `enum` keyword).

- **Integer/Double**:
  - `JSONSchema.Internal(type: .integer)` or `JSONSchema.Internal(type: .number)`.
  - Apply guides.

- **Boolean**:
  - `JSONSchema.Internal(type: .boolean)`.

- **Array**:
  - `JSONSchema.Internal(type: .array)`.
  - `internalItem.items = process(itemType.jsonSchema, isRoot: false)`.

- **Object**:
  - `JSONSchema.Internal(type: .object)`.
  - `internal.additionalProperties = false`
  - Properties: `internal.properties = [:]`.
  - **Ordering**:
    - `orderedNames = schema.properties.map(\.name)`
    - If `target == .gemini`: `internal.propertyOrdering = orderedNames`
    - If `target == .apple`: `internal.xOrder = orderedNames`
  - For each `property`:
    - `propSchema = property.type.jsonSchema`.
    - `internalProp = process(propSchema, ...)`
    - **Guide Merging**:
      - `internalProp.description = property.description ?? internalProp.description`
      - Apply guides from `property.guides`.
      - *Rule*: Property-level guides are **merged** with Type-level guides using an **intersection**
        strategy (narrowing). For example, if Type has `min: 0` and Property has `min: 10`, the
        result is `min: 10`. Orthogonal guides are also merged.
    - `internal.properties![property.name] = internalProp`
    - If `!property.isOptional`:
      - Append `name` to `required`.
    - Note: If `property.isOptional`, it is simply omitted from `required`. We do not set
      `nullable`.

- **AnyOf**:
  - `JSONSchema.Internal(anyOf: [])`.
  - For each type:
    - Append `process(subSchema, isRoot: false)`.

## Edge Cases & Considerations

1. **Recursive Root**:
   - If a child refers to the root type (by identifier), it is encoded as `["$ref": "#"]`.
   - This works regardless of whether the root has a title.
   - We must capture the `rootIdentifier` at the start of encoding.

2. **Nil Titles & Infinite Recursion**:
   - Anonymous objects (nil title) are always inlined.
   - If a nested anonymous type refers back to itself (or an ancestor in the current inline chain),
     we cannot create a Ref (no title) and cannot inline (infinite loop).
   - **Action**: We track `codingPath`. If we encounter a type already in `codingPath` that wasn't
     handled by Root/Def Ref logic, we throw `SchemaError.circularDependency`.

3. **Property Specifics**:
   - `Property` has `guides` (AnyGenerationGuides).
   - These verify/constrain the value.
   - We need to merge these guides into the schema.
   - **Precedence**: Property guides > Type guides.

4. **Concurrency**:
   - The encoder is likely single-threaded usage or transient.
   - `JSONSchema` is `Sendable`.

## Implementation Steps

1. Draft `SchemaEncoder` struct.
2. Implement `encode(_:)` entry point.
3. Implement `process(_:isRoot:)`.
4. Implement `encodeBody(_:)` for each Kind.
5. Add unit tests for recursive structures and basic types.

## Appendix: Existing Source Code

### `FirebaseAI/Sources/Types/Public/StructuredOutput/JSONSchema.swift`

```swift
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
public struct JSONSchema: Sendable {
  enum Kind: Sendable {
    case string(guides: StringGuides)
    case integer(guides: IntegerGuides)
    case double(guides: DoubleGuides)
    case boolean
    case array(item: any FirebaseGenerable.Type, guides: ArrayGuides)
    case object(properties: [Property])
    case anyOf(types: [any FirebaseGenerable.Type])
  }

  let type: any FirebaseGenerable.Type
  let kind: Kind
  let typeIdentifier: ObjectIdentifier
  let title: String?
  let description: String?

  init(type: any FirebaseGenerable.Type, kind: Kind, title: String? = nil,
       description: String? = nil) {
    self.kind = kind
    self.type = type
    typeIdentifier = ObjectIdentifier(type)
    self.title = title
    self.description = description
  }

  public struct Property: Sendable {
    let name: String
    let description: String?
    let isOptional: Bool
    let type: any FirebaseGenerable.Type
    let guides: AnyGenerationGuides

    public init<Value>(name: String, description: String? = nil, type: Value.Type,
                       guides: [FirebaseGenerationGuide<Value>] = [])
      where Value: FirebaseGenerable {
      self.name = name
      self.description = description
      isOptional = false
      self.type = Value.self
      self.guides = AnyGenerationGuides.combine(guides: guides)
    }

    public init<Value>(name: String, description: String? = nil, type: Value?.Type,
                       guides: [FirebaseGenerationGuide<Value>] = [])
      where Value: FirebaseGenerable {
      self.name = name
      self.description = description
      isOptional = true
      self.type = Value.self
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
      kind: .anyOf(types: types),
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

    public var errorDescription: String? { nil }
    public var recoverySuggestion: String? { nil }
  }
}
```

### `FirebaseAI/Sources/Types/Internal/StructuredOutput/AnyGenerationGuides.swift`

```swift
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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class AnyGenerationGuides: Sendable {
  let string: StringGuides?
  let integer: IntegerGuides?
  let double: DoubleGuides?
  let array: ArrayGuides?

  init(string: StringGuides? = nil,
       integer: IntegerGuides? = nil,
       double: DoubleGuides? = nil,
       array: ArrayGuides? = nil) {
    assert([string as Any?, integer, double, array].compactMap { $0 }.count <= 1)
    self.string = string
    self.integer = integer
    self.double = double
    self.array = array
  }

  static func combine<Value>(guides: [FirebaseGenerationGuide<Value>]) -> AnyGenerationGuides {
    return combine(guides: guides.map { $0.wrapped })
  }

  static func combine(guides: [AnyGenerationGuides]) -> AnyGenerationGuides {
    let generationGuides = AnyGenerationGuides(
      string: StringGuides.combine(guides.compactMap { $0.string }),
      integer: IntegerGuides.combine(guides.compactMap { $0.integer }),
      double: DoubleGuides.combine(guides.compactMap { $0.double }),
      array: ArrayGuides.combine(guides.compactMap { $0.array })
    )
    assert([
      generationGuides.string as Any?,
      generationGuides.integer,
      generationGuides.double,
      generationGuides.array,
    ].compactMap { $0 }.count <= 1)

    return generationGuides
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct StringGuides: Sendable {
  let anyOf: [String]?

  init(anyOf: [String]? = nil) {
    self.anyOf = anyOf
  }

  static func combine(_ guides: [StringGuides]) -> StringGuides? {
    guard !guides.isEmpty else { return nil }
    var combinedAnyOf: Set<String>?

    for guide in guides {
      if let anyOf = guide.anyOf {
        if combinedAnyOf == nil {
          combinedAnyOf = Set(anyOf)
        } else {
          combinedAnyOf?.formIntersection(anyOf)
        }
      }
    }

    return StringGuides(anyOf: combinedAnyOf.map(Array.init))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct IntegerGuides: Sendable {
  let minimum: Int?
  let maximum: Int?

  init(minimum: Int? = nil, maximum: Int? = nil) {
    self.minimum = minimum
    self.maximum = maximum
  }

  static func combine(_ guides: [IntegerGuides]) -> IntegerGuides? {
    guard !guides.isEmpty else { return nil }
    var minimum: Int?
    var maximum: Int?

    for guide in guides {
      if let guideMin = guide.minimum {
        minimum = max(minimum ?? guideMin, guideMin)
      }
      if let guideMax = guide.maximum {
        maximum = min(maximum ?? guideMax, guideMax)
      }
    }

    return IntegerGuides(minimum: minimum, maximum: maximum)
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct DoubleGuides: Sendable {
  let minimum: Double?
  let maximum: Double?

  init(minimum: Double? = nil, maximum: Double? = nil) {
    self.minimum = minimum
    self.maximum = maximum
  }

  static func combine(_ guides: [DoubleGuides]) -> DoubleGuides? {
    guard !guides.isEmpty else { return nil }
    var minimum: Double?
    var maximum: Double?

    for guide in guides {
      if let guideMin = guide.minimum {
        minimum = max(minimum ?? guideMin, guideMin)
      }
      if let guideMax = guide.maximum {
        maximum = min(maximum ?? guideMax, guideMax)
      }
    }

    return DoubleGuides(minimum: minimum, maximum: maximum)
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct ArrayGuides: Sendable {
  let minimumCount: Int?
  let maximumCount: Int?
  let element: AnyGenerationGuides?

  init(minimumCount: Int? = nil, maximumCount: Int? = nil, element: AnyGenerationGuides? = nil) {
    self.minimumCount = minimumCount
    self.maximumCount = maximumCount
    self.element = element
  }

  static func combine(_ guides: [ArrayGuides]) -> ArrayGuides? {
    guard !guides.isEmpty else { return nil }
    var minimumCount: Int?
    var maximumCount: Int?
    var elementGuides: [AnyGenerationGuides] = []

    for guide in guides {
      if let guideMin = guide.minimumCount {
        minimumCount = max(minimumCount ?? guideMin, guideMin)
      }
      if let guideMax = guide.maximumCount {
        maximumCount = min(maximumCount ?? guideMax, guideMax)
      }
      if let element = guide.element {
        elementGuides.append(element)
      }
    }

    return ArrayGuides(
      minimumCount: minimumCount,
      maximumCount: maximumCount,
      element: elementGuides.isEmpty ? nil : AnyGenerationGuides.combine(guides: elementGuides)
    )
  }
}
```

### `FirebaseAI/Sources/JSONValue.swift`

```swift
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

/// A collection of name-value pairs representing a JSON object.
///
/// This may be decoded from, or encoded to, a
/// [`google.protobuf.Struct`](https://protobuf.dev/reference/protobuf/google.protobuf/#struct).
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias JSONObject = [String: JSONValue]

/// Represents a value in one of JSON's data types.
///
/// This may be decoded from, or encoded to, a
/// [`google.protobuf.Value`](https://protobuf.dev/reference/protobuf/google.protobuf/#value).
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public enum JSONValue: Sendable {
  /// A `null` value.
  case null

  /// A numeric value.
  case number(Double)

  /// A string value.
  case string(String)

  /// A boolean value.
  case bool(Bool)

  /// A JSON object.
  case object(JSONObject)

  /// An array of `JSONValue`s.
  case array([JSONValue])
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension JSONValue: Decodable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let numberValue = try? container.decode(Double.self) {
      self = .number(numberValue)
    } else if let stringValue = try? container.decode(String.self) {
      self = .string(stringValue)
    } else if let boolValue = try? container.decode(Bool.self) {
      self = .bool(boolValue)
    } else if let objectValue = try? container.decode(JSONObject.self) {
      self = .object(objectValue)
    } else if let arrayValue = try? container.decode([JSONValue].self) {
      self = .array(arrayValue)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Failed to decode JSON value."
      )
    }
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension JSONValue: Encodable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null:
      try container.encodeNil()
    case let .number(numberValue):
      // Convert to `Decimal` before encoding for consistent floating-point serialization across
      // platforms. E.g., `Double` serializes 3.14159 as 3.1415899999999999 in some cases and
      // 3.14159 in others. See
      // https://forums.swift.org/t/jsonencoder-encodable-floating-point-rounding-error/41390/4 for
      // more details.
      try container.encode(Decimal(numberValue))
    case let .string(stringValue):
      try container.encode(stringValue)
    case let .bool(boolValue):
      try container.encode(boolValue)
    case let .object(objectValue):
      try container.encode(objectValue)
    case let .array(arrayValue):
      try container.encode(arrayValue)
    }
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension JSONValue: Equatable {}
```
