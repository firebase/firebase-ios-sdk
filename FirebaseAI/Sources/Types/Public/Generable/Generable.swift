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
public protocol Generable: ConvertibleFromGeneratedContent, ConvertibleToGeneratedContent {
  /// An instance of the generation schema.
  static var generationSchema: GenerationSchema { get }
}

extension Optional where Wrapped: Generable {}

extension Optional: ConvertibleToGeneratedContent where Wrapped: ConvertibleToGeneratedContent {
  public var generatedContent: GeneratedContent {
    guard let self else { return GeneratedContent(kind: .null) }

    return GeneratedContent(self)
  }
}

extension Bool: Generable {
  public static var generationSchema: GenerationSchema {
    GenerationSchema(kind: .boolean, source: "Bool")
  }

  public init(_ content: GeneratedContent) throws {
    guard case let .bool(value) = content.kind else {
      // TODO: Determine the correct error to throw.
      fatalError("Expected a boolean but found \(content.kind)")
    }
    self = value
  }

  public var generatedContent: GeneratedContent {
    return GeneratedContent(kind: .bool(self))
  }
}

extension String: Generable {
  public static var generationSchema: GenerationSchema {
    GenerationSchema(kind: .string, source: "String")
  }

  public init(_ content: GeneratedContent) throws {
    guard case let .string(value) = content.kind else {
      // TODO: Determine the correct error to throw.
      fatalError("Expected a string but found \(content.kind)")
    }
    self = value
  }

  public var generatedContent: GeneratedContent {
    return GeneratedContent(kind: .string(self))
  }
}

extension Int: Generable {
  public static var generationSchema: GenerationSchema {
    GenerationSchema(kind: .integer, source: "Int")
  }

  public init(_ content: GeneratedContent) throws {
    // TODO: Determine the correct errors to throw.
    guard case let .number(value) = content.kind else {
      fatalError("Expected a number but found \(content.kind)")
    }
    guard let integer = Int(exactly: value) else {
      fatalError("Expected an integer but found \(value)")
    }
    self = integer
  }

  public var generatedContent: GeneratedContent {
    return GeneratedContent(kind: .number(Double(self)))
  }
}

extension Float: Generable {
  public static var generationSchema: GenerationSchema {
    GenerationSchema(kind: .double, source: "Number")
  }

  public init(_ content: GeneratedContent) throws {
    // TODO: Determine the correct error to throw.
    guard case let .number(value) = content.kind else {
      fatalError("Expected a number but found \(content.kind)")
    }
    guard let float = Float(exactly: value) else {
      fatalError("Expected a float but found \(value)")
    }
    self = float
  }

  public var generatedContent: GeneratedContent {
    return GeneratedContent(kind: .number(Double(self)))
  }
}

extension Double: Generable {
  public static var generationSchema: GenerationSchema {
    GenerationSchema(kind: .double, source: "Number")
  }

  public init(_ content: GeneratedContent) throws {
    // TODO: Determine the correct error to throw.
    guard case let .number(value) = content.kind else {
      fatalError("Expected a number but found \(content.kind)")
    }
    guard let double = Double(exactly: value) else {
      fatalError("Expected a double but found \(value)")
    }
    self = double
  }

  public var generatedContent: GeneratedContent {
    return GeneratedContent(kind: .number(self))
  }
}

extension Decimal: Generable {
  public static var generationSchema: GenerationSchema {
    GenerationSchema(kind: .double, source: "Number")
  }

  public init(_ content: GeneratedContent) throws {
    // TODO: Determine the correct error to throw.
    guard case let .number(value) = content.kind else {
      fatalError("Expected a number but found \(content.kind)")
    }
    self = Decimal(value)
  }

  public var generatedContent: GeneratedContent {
    let doubleValue = (self as NSDecimalNumber).doubleValue
    return GeneratedContent(kind: .number(doubleValue))
  }
}

extension Array: Generable where Element: Generable {
  public static var generationSchema: GenerationSchema {
    GenerationSchema(kind: .array(item: Element.self), source: String(describing: self))
  }
}

extension Array: ConvertibleToGeneratedContent where Element: ConvertibleToGeneratedContent {
  public var generatedContent: GeneratedContent {
    let values = map { $0.generatedContent }
    return GeneratedContent(kind: .array(values))
  }
}

extension Array: ConvertibleFromGeneratedContent where Element: ConvertibleFromGeneratedContent {
  public init(_ content: GeneratedContent) throws {
    // TODO: Determine the correct error to throw.
    guard case let .array(values) = content.kind else {
      fatalError("Expected an array but found \(content.kind)")
    }
    self = try values.map { try Element($0) }
  }
}
