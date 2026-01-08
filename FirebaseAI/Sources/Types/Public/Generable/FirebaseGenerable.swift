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

/// A type that the model uses when responding to prompts.
///
/// Annotate your Swift structure or enumeration with the `@Generable` macro to allow the model to
/// respond to prompts by generating an instance of your type. Use the `@Guide` macro to provide
/// natural language descriptions of your properties, and programmatically control the values that
/// the model can generate.
///
/// ```swift
/// @Generable
/// struct SearchSuggestions {
///     @Guide(description: "A list of suggested search terms", .count(4))
///     var searchTerms: [SearchTerm]
///
///     @Generable
///     struct SearchTerm {
///         // Use a generation identifier for data structures the framework generates.
///         var id: GenerationID
///
///         @Guide(description: "A 2 or 3 word search term, like 'Beautiful sunsets'")
///         var searchTerm: String
///     }
/// }
/// ```
/// - SeeAlso: `@Generable` macro ``Generable(description:)`` and  `@Guide` macro
/// ``Guide(description:)``.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public protocol FirebaseGenerable: ConvertibleFromModelOutput, ConvertibleToModelOutput {
  /// A representation of partially generated content
  // associatedtype PartiallyGenerated: ConvertibleFromModelOutput = Self

  /// An instance of the JSON schema.
  static var jsonSchema: JSONSchema { get }
}

// @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
// public extension Optional where Wrapped: FirebaseGenerable {
//  typealias PartiallyGenerated = Wrapped.PartiallyGenerated
// }

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Optional: ConvertibleToModelOutput where Wrapped: ConvertibleToModelOutput {
  public var modelOutput: ModelOutput {
    guard let self else { return ModelOutput(kind: .null) }

    return ModelOutput(self)
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Bool: FirebaseGenerable {
  public static var jsonSchema: JSONSchema {
    JSONSchema(kind: .boolean(description: nil), source: "Bool")
  }

  public init(_ content: ModelOutput) throws {
    guard case let .bool(value) = content.kind else {
      throw Self.decodingFailure(content)
    }
    self = value
  }

  public var modelOutput: ModelOutput {
    return ModelOutput(kind: .bool(self))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension String: FirebaseGenerable {
  public static var jsonSchema: JSONSchema {
    JSONSchema(
      kind: .string(name: nil, description: nil, guides: StringGuides()),
      source: "String"
    )
  }

  public init(_ content: ModelOutput) throws {
    guard case let .string(value) = content.kind else {
      throw Self.decodingFailure(content)
    }
    self = value
  }

  public var modelOutput: ModelOutput {
    return ModelOutput(kind: .string(self))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Int: FirebaseGenerable {
  public static var jsonSchema: JSONSchema {
    JSONSchema(kind: .integer(description: nil, guides: IntegerGuides()), source: "Int")
  }

  public init(_ content: ModelOutput) throws {
    guard case let .number(value) = content.kind, let integer = Int(exactly: value) else {
      throw Self.decodingFailure(content)
    }
    self = integer
  }

  public var modelOutput: ModelOutput {
    return ModelOutput(kind: .number(Double(self)))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Float: FirebaseGenerable {
  public static var jsonSchema: JSONSchema {
    JSONSchema(kind: .double(description: nil, guides: DoubleGuides()), source: "Number")
  }

  public init(_ content: ModelOutput) throws {
    guard case let .number(value) = content.kind else {
      throw Self.decodingFailure(content)
    }
    self = Float(value)
  }

  public var modelOutput: ModelOutput {
    return ModelOutput(kind: .number(Double(self)))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Double: FirebaseGenerable {
  public static var jsonSchema: JSONSchema {
    JSONSchema(kind: .double(description: nil, guides: DoubleGuides()), source: "Number")
  }

  public init(_ content: ModelOutput) throws {
    guard case let .number(value) = content.kind else {
      throw Self.decodingFailure(content)
    }
    self = value
  }

  public var modelOutput: ModelOutput {
    return ModelOutput(kind: .number(self))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Decimal: FirebaseGenerable {
  public static var jsonSchema: JSONSchema {
    JSONSchema(kind: .double(description: nil, guides: DoubleGuides()), source: "Number")
  }

  public init(_ content: ModelOutput) throws {
    guard case let .number(value) = content.kind else {
      throw Self.decodingFailure(content)
    }
    self = Decimal(value)
  }

  public var modelOutput: ModelOutput {
    let doubleValue = (self as NSDecimalNumber).doubleValue
    return ModelOutput(kind: .number(doubleValue))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Array: FirebaseGenerable where Element: FirebaseGenerable {
  /// A representation of partially generated content
  // public typealias PartiallyGenerated = [Element.PartiallyGenerated]

  public static var jsonSchema: JSONSchema {
    JSONSchema(
      kind: .array(description: nil, item: Element.self, guides: ArrayGuides()),
      source: String(describing: self)
    )
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Array: ConvertibleToModelOutput where Element: ConvertibleToModelOutput {
  public var modelOutput: ModelOutput {
    let values = map { $0.modelOutput }
    return ModelOutput(kind: .array(values))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Array: ConvertibleFromModelOutput where Element: ConvertibleFromModelOutput {
  public init(_ content: ModelOutput) throws {
    guard case let .array(values) = content.kind else {
      throw Self.decodingFailure(content)
    }
    self = try values.map { try Element($0) }
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
private extension ConvertibleFromModelOutput {
  /// Helper method to create ``GenerativeModel/GenerationError/decodingFailure(_:)`` instances.
  static func decodingFailure(_ content: ModelOutput) -> GenerativeModel.GenerationError {
    return GenerativeModel.GenerationError.decodingFailure(
      GenerativeModel.GenerationError.Context(debugDescription: """
      \(content.self) does not contain \(Self.self).
      Content: \(content)
      """)
    )
  }
}
