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

/// A type that represents structured model output.
///
/// Model output may contain a single value, an array, or key-value pairs with unique keys.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ModelOutput: Sendable, Generable {
  /// The kind representation of this model output.
  ///
  /// This property provides access to the content in a strongly-typed enum representation,
  /// preserving the hierarchical structure of the data and the  data's ``GenerationID`` ids.
  public let kind: Kind

  /// An instance of the JSON schema.
  public static var jsonSchema: JSONSchema {
    // Return a schema equivalent to any legal JSON, i.e.:
    // {
    //   "anyOf" : [
    //     {
    //       "additionalProperties" : {
    //         "$ref" : "#"
    //       },
    //       "type" : "object"
    //     },
    //     {
    //       "items" : {
    //         "$ref" : "#"
    //       },
    //       "type" : "array"
    //     },
    //     {
    //       "type" : "boolean"
    //     },
    //     {
    //       "type" : "number"
    //     },
    //     {
    //       "type" : "string"
    //     }
    //   ],
    //   "description" : "Any legal JSON",
    //   "title" : "ModelOutput"
    // }
    fatalError("`ModelOutput.generationSchema` is not implemented.")
  }

  init(kind: Kind) {
    self.kind = kind
  }

  /// Creates model output from another value.
  ///
  /// This is used to satisfy `Generable.init(_:)`.
  public init(_ content: ModelOutput) throws {
    self = content
  }

  /// A representation of this instance.
  public var modelOutput: ModelOutput { self }

  /// Creates model output representing a structure with the properties you specify.
  ///
  /// The order of properties is important. For ``Generable`` types, the order must match the order
  /// properties in the types `schema`.
  public init(properties: KeyValuePairs<String, any ConvertibleToModelOutput>) {
    fatalError("`ModelOutput.init(properties:)` is not implemented.")
  }

  /// Creates new model output from the key-value pairs in the given sequence, using a
  /// combining closure to determine the value for any duplicate keys.
  ///
  /// The order of properties is important. For ``Generable`` types, the order must match the order
  /// properties in the types `schema`.
  ///
  /// You use this initializer to create model output when you have a sequence of key-value
  /// tuples that might have duplicate keys. As the content is built, the initializer calls the
  /// `combine` closure with the current and new values for any duplicate keys. Pass a closure as
  /// `combine` that returns the value to use in the resulting content: The closure can choose
  /// between the two values, combine them to produce a new value, or even throw an error.
  ///
  /// The following example shows how to choose the first and last values for any duplicate keys:
  ///
  /// ```swift
  ///     let content = ModelOutput(
  ///       properties: [("name", "John"), ("name", "Jane"), ("married", true)],
  ///       uniquingKeysWith: { (first, _) in first }
  ///     )
  ///     // ModelOutput(["name": "John", "married": true])
  /// ```
  ///
  /// - Parameters:
  ///   - properties: A sequence of key-value pairs to use for the new content.
  ///   - id: A unique id associated with ``ModelOutput``.
  ///   - combine: A closure that is called with the values to resolve any duplicates
  ///     keys that are encountered. The closure returns the desired value for the final content.
  public init<S>(properties: S,
                 uniquingKeysWith combine: (ModelOutput, ModelOutput) throws
                   -> some ConvertibleToModelOutput) rethrows where S: Sequence, S.Element == (
    String,
    any ConvertibleToModelOutput
  ) {
    var propertyNames = [String]()
    var propertyMap = [String: ModelOutput]()
    for (key, value) in properties {
      if !propertyNames.contains(key) {
        propertyNames.append(key)
        propertyMap[key] = value.modelOutput
      } else {
        guard let existingProperty = propertyMap[key] else {
          // TODO: Figure out an error to throw
          fatalError()
        }
        let deduplicatedProperty = try combine(existingProperty, value.modelOutput)
        propertyMap[key] = deduplicatedProperty.modelOutput
      }
    }

    kind = .structure(properties: propertyMap, orderedKeys: propertyNames)
  }

  /// Creates content representing an array of elements you specify.
  public init<S>(elements: S) where S: Sequence, S.Element == any ConvertibleToModelOutput {
    fatalError("`ModelOutput.init(elements:)` is not implemented.")
  }

  /// Creates content that contains a single value.
  ///
  /// - Parameters:
  ///   - value: The underlying value.
  public init(_ value: some ConvertibleToModelOutput) {
    self = value.modelOutput
  }

  /// Reads a top level, concrete partially `Generable` type from a named property.
  public func value<Value>(_ type: Value.Type = Value.self) throws -> Value
    where Value: ConvertibleFromModelOutput {
    return try Value(self)
  }

  /// Reads a concrete `Generable` type from named property.
  public func value<Value>(_ type: Value.Type = Value.self,
                           forProperty property: String) throws -> Value
    where Value: ConvertibleFromModelOutput {
    guard case let .structure(properties, _) = kind else {
      throw DecodingError.notAStructure
    }
    guard let value = properties[property] else {
      throw DecodingError.missingProperty(name: property)
    }

    return try Value(value)
  }

  /// Reads an optional, concrete generable type from named property.
  public func value<Value>(_ type: Value?.Type = Value?.self,
                           forProperty property: String) throws -> Value?
    where Value: ConvertibleFromModelOutput {
    guard case let .structure(properties, _) = kind else {
      throw DecodingError.notAStructure
    }
    guard let value = properties[property] else {
      return nil
    }

    return try Value(value)
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension ModelOutput {
  /// An error that occurs when decoding a value from `ModelOutput`.
  enum DecodingError: Error {
    /// A required property was not found in the `ModelOutput`.
    case missingProperty(name: String)

    /// A property was accessed on a `ModelOutput` that is not a structure.
    case notAStructure

    /// The type of a property in the `ModelOutput` did not match the expected type.
    case typeMismatch(expected: Any.Type, actual: Any.Type)
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension ModelOutput {
  /// A representation of the different types of content that can be stored in `ModelOutput`.
  ///
  /// `Kind` represents the various types of JSON-compatible data that can be held within a
  /// ``ModelOutput`` instance, including primitive types, arrays, and structured objects.
  enum Kind: Sendable {
    /// Represents a null value.
    case null

    /// Represents a boolean value.
    /// - Parameter value: The boolean value.
    case bool(Bool)

    /// Represents a numeric value.
    /// - Parameter value: The numeric value as a Double.
    case number(Double)

    /// Represents a string value.
    /// - Parameter value: The string value.
    case string(String)

    /// Represents an array of `ModelOutput` elements.
    /// - Parameter elements: An array of ``ModelOutput`` instances.
    case array([ModelOutput])

    /// Represents a structured object with key-value pairs.
    /// - Parameters:
    ///   - properties: A dictionary mapping string keys to ``ModelOutput`` values.
    ///   - orderedKeys: An array of keys that specifies the order of properties.
    case structure(properties: [String: ModelOutput], orderedKeys: [String])
  }
}
