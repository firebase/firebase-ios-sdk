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
public protocol FirebaseGenerable: ConvertibleFromFirebaseGeneratedContent,
  ConvertibleToFirebaseGeneratedContent {
  associatedtype PartiallyGenerated: ConvertibleFromFirebaseGeneratedContent

  static var firebaseGenerationSchema: FirebaseGenerationSchema { get }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FirebaseGenerable {
  typealias PartiallyGenerated = Self
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Optional where Wrapped: FirebaseGenerable {
  typealias PartiallyGenerated = Wrapped.PartiallyGenerated
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Optional: ConvertibleToFirebaseGeneratedContent
  where Wrapped: ConvertibleToFirebaseGeneratedContent {
  public var firebaseGeneratedContent: FirebaseGeneratedContent {
    guard let self else { return FirebaseGeneratedContent(kind: .null) }

    return FirebaseGeneratedContent(self)
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Optional: ConvertibleFromFirebaseGeneratedContent
  where Wrapped: ConvertibleFromFirebaseGeneratedContent {
  public init(_ content: FirebaseGeneratedContent) throws {
    if case .null = content.kind {
      self = nil
      return
    }
    self = try Wrapped(content)
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Bool: FirebaseGenerable {
  public typealias PartiallyGenerated = Self

  public static var firebaseGenerationSchema: FirebaseGenerationSchema {
    FirebaseGenerationSchema(type: Bool.self, kind: .boolean)
  }

  public init(_ content: FirebaseGeneratedContent) throws {
    guard case let .bool(value) = content.kind else {
      throw Self.decodingFailure(content)
    }
    self = value
  }

  public var firebaseGeneratedContent: FirebaseGeneratedContent {
    return FirebaseGeneratedContent(kind: .bool(self))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension String: FirebaseGenerable {
  public typealias PartiallyGenerated = Self

  public static var firebaseGenerationSchema: FirebaseGenerationSchema {
    FirebaseGenerationSchema(type: String.self, kind: .string(guides: StringGuides()))
  }

  public init(_ content: FirebaseGeneratedContent) throws {
    guard case let .string(value) = content.kind else {
      throw Self.decodingFailure(content)
    }
    self = value
  }

  public var firebaseGeneratedContent: FirebaseGeneratedContent {
    return FirebaseGeneratedContent(kind: .string(self))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Int: FirebaseGenerable {
  public typealias PartiallyGenerated = Self

  public static var firebaseGenerationSchema: FirebaseGenerationSchema {
    FirebaseGenerationSchema(type: Int.self, kind: .integer(guides: IntegerGuides()))
  }

  public init(_ content: FirebaseGeneratedContent) throws {
    guard case let .number(value) = content.kind, let integer = Int(exactly: value) else {
      throw Self.decodingFailure(content)
    }
    self = integer
  }

  public var firebaseGeneratedContent: FirebaseGeneratedContent {
    return FirebaseGeneratedContent(kind: .number(Double(self)))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Float: FirebaseGenerable {
  public typealias PartiallyGenerated = Self

  public static var firebaseGenerationSchema: FirebaseGenerationSchema {
    FirebaseGenerationSchema(type: Float.self, kind: .double(guides: DoubleGuides()))
  }

  public init(_ content: FirebaseGeneratedContent) throws {
    guard case let .number(value) = content.kind else {
      throw Self.decodingFailure(content)
    }
    self = Float(value)
  }

  public var firebaseGeneratedContent: FirebaseGeneratedContent {
    return FirebaseGeneratedContent(kind: .number(Double(self)))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Double: FirebaseGenerable {
  public typealias PartiallyGenerated = Self

  public static var firebaseGenerationSchema: FirebaseGenerationSchema {
    FirebaseGenerationSchema(type: Double.self, kind: .double(guides: DoubleGuides()))
  }

  public init(_ content: FirebaseGeneratedContent) throws {
    guard case let .number(value) = content.kind else {
      throw Self.decodingFailure(content)
    }
    self = value
  }

  public var firebaseGeneratedContent: FirebaseGeneratedContent {
    return FirebaseGeneratedContent(kind: .number(self))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Decimal: FirebaseGenerable {
  public typealias PartiallyGenerated = Self

  public static var firebaseGenerationSchema: FirebaseGenerationSchema {
    FirebaseGenerationSchema(type: Decimal.self, kind: .double(guides: DoubleGuides()))
  }

  public init(_ content: FirebaseGeneratedContent) throws {
    guard case let .number(value) = content.kind else {
      throw Self.decodingFailure(content)
    }
    self = Decimal(value)
  }

  public var firebaseGeneratedContent: FirebaseGeneratedContent {
    return FirebaseGeneratedContent(kind: .number(doubleValue))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Array: FirebaseGenerable where Element: FirebaseGenerable {
  public typealias PartiallyGenerated = [Element.PartiallyGenerated]

  public static var firebaseGenerationSchema: FirebaseGenerationSchema {
    FirebaseGenerationSchema(
      type: Self.self,
      kind: .array(item: FirebaseGenerableType(Element.self), guides: ArrayGuides())
    )
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Array: ConvertibleToFirebaseGeneratedContent
  where Element: ConvertibleToFirebaseGeneratedContent {
  public var firebaseGeneratedContent: FirebaseGeneratedContent {
    let values = map { $0.firebaseGeneratedContent }
    return FirebaseGeneratedContent(kind: .array(values))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Array: ConvertibleFromFirebaseGeneratedContent
  where Element: ConvertibleFromFirebaseGeneratedContent {
  public init(_ content: FirebaseGeneratedContent) throws {
    guard case let .array(values) = content.kind else {
      throw Self.decodingFailure(content)
    }
    self = try values.map { try Element($0) }
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
private extension ConvertibleFromFirebaseGeneratedContent {
  /// Helper method to create ``GenerativeModel/GenerationError/decodingFailure(_:)`` instances.
  static func decodingFailure(_ content: FirebaseGeneratedContent) -> GenerativeModel
    .GenerationError {
    return GenerativeModel.GenerationError.decodingFailure(
      GenerativeModel.GenerationError.Context(debugDescription: """
      \(content.self) does not contain \(Self.self).
      Content: \(content)
      """)
    )
  }
}
