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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public protocol FirebaseGenerable: ConvertibleFromModelOutput, ConvertibleToModelOutput {
  associatedtype Partial: ConvertibleFromModelOutput = Self

  static var jsonSchema: JSONSchema { get }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FirebaseGenerable {
  typealias Partial = Self
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Optional where Wrapped: FirebaseGenerable {
  typealias Partial = Wrapped.Partial
}

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
    JSONSchema(type: Bool.self, kind: .boolean)
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
    JSONSchema(type: String.self, kind: .string(guides: StringGuides()))
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
    JSONSchema(type: Int.self, kind: .integer(guides: IntegerGuides()))
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
    JSONSchema(type: Float.self, kind: .double(guides: DoubleGuides()))
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
    JSONSchema(type: Double.self, kind: .double(guides: DoubleGuides()))
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
    JSONSchema(type: Decimal.self, kind: .double(guides: DoubleGuides()))
  }

  public init(_ content: ModelOutput) throws {
    guard case let .number(value) = content.kind else {
      throw Self.decodingFailure(content)
    }
    self = Decimal(value)
  }

  public var modelOutput: ModelOutput {
    return ModelOutput(kind: .number(doubleValue))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Array: FirebaseGenerable where Element: FirebaseGenerable {
  public static var jsonSchema: JSONSchema {
    JSONSchema(
      type: Self.self,
      kind: .array(item: FirebaseGenerableType(Element.self), guides: ArrayGuides())
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
