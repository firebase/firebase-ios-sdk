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
#if canImport(FoundationModels)
  public import protocol FoundationModels.ConvertibleFromGeneratedContent
  public import protocol FoundationModels.ConvertibleToGeneratedContent
  public import struct FoundationModels.GeneratedContent
#endif // canImport(FoundationModels)

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ModelOutput: Sendable, CustomDebugStringConvertible, FirebaseGenerable {
  public let kind: Kind

  public static var jsonSchema: JSONSchema {
    fatalError("`ModelOutput.jsonSchema` is not implemented.")
  }

  public var id: ResponseID?

  init(kind: Kind, id: ResponseID? = nil) {
    self.kind = kind
  }

  public var debugDescription: String {
    return kind.debugDescription
  }

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

  public init<S>(elements: S) where S: Sequence, S.Element == any ConvertibleToModelOutput {
    fatalError("`ModelOutput.init(elements:)` is not implemented.")
  }

  public init(_ value: some ConvertibleToModelOutput) {
    self = value.modelOutput
  }

  public init(json: String, id: ResponseID? = nil) throws {
    guard let jsonData = json.data(using: .utf8) else {
      fatalError()
    }

    let jsonValue = try JSONDecoder().decode(JSONValue.self, from: jsonData)
    var modelOutput = jsonValue.modelOutput
    modelOutput.id = id

    self = modelOutput
  }

  public func value<Value>(_ type: Value.Type = Value.self) throws -> Value
    where Value: ConvertibleFromModelOutput {
    return try Value(self)
  }

  public func value<Value>(_ type: Value.Type = Value.self,
                           forProperty property: String) throws -> Value
    where Value: ConvertibleFromModelOutput {
    guard case let .structure(properties, _) = kind else {
      throw GenerativeModel.GenerationError.decodingFailure(
        GenerativeModel.GenerationError.Context(debugDescription: """
        \(Self.self) does not contain an object.
        Content: \(kind)
        """)
      )
    }
    guard let value = properties[property] else {
      throw GenerativeModel.GenerationError.decodingFailure(
        GenerativeModel.GenerationError.Context(debugDescription: """
        \(Self.self) does not contain a property '\(property)'.
        Content: \(self)
        """)
      )
    }

    return try Value(value)
  }

  public func value<Value>(_ type: Value?.Type = Value?.self,
                           forProperty property: String) throws -> Value?
    where Value: ConvertibleFromModelOutput {
    guard case let .structure(properties, _) = kind else {
      throw GenerativeModel.GenerationError.decodingFailure(
        GenerativeModel.GenerationError.Context(debugDescription: """
        \(Self.self) does not contain an object.
        Content: \(kind)
        """)
      )
    }
    guard let value = properties[property] else {
      return nil
    }

    if case .null = value.kind {
      return nil
    }

    return try Value(value)
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ModelOutput: ConvertibleFromModelOutput {
  public init(_ content: ModelOutput) throws {
    self = content
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ModelOutput: ConvertibleToModelOutput {
  public var modelOutput: ModelOutput { self }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension ModelOutput {
  enum Kind: Sendable, CustomDebugStringConvertible {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([ModelOutput])
    case structure(properties: [String: ModelOutput], orderedKeys: [String])

    public var debugDescription: String {
      switch self {
      case .null:
        return "null"
      case let .bool(value):
        return String(describing: value)
      case let .number(value):
        return String(describing: value)
      case let .string(value):
        return #""\#(value)""#
      case let .array(elements):
        let descriptions = elements.map { $0.debugDescription }
        return "[\(descriptions.joined(separator: ", "))]"
      case let .structure(properties, orderedKeys):
        let descriptions = orderedKeys.compactMap { key -> String? in
          guard let value = properties[key] else { return nil }
          return #""\#(key)": \#(value.debugDescription)"#
        }
        return "{\(descriptions.joined(separator: ", "))}"
      }
    }
  }
}

#if canImport(FoundationModels)
  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  extension ModelOutput: ConvertibleToGeneratedContent {
    public var generatedContent: GeneratedContent {
      switch kind {
      case .null:
        return GeneratedContent(kind: .null)
      case let .bool(value):
        return GeneratedContent(kind: .bool(value))
      case let .number(value):
        return GeneratedContent(kind: .number(value))
      case let .string(value):
        return GeneratedContent(kind: .string(value))
      case let .array(values):
        return GeneratedContent(kind: .array(values.map { $0.generatedContent }))
      case let .structure(properties: properties, orderedKeys: orderedKeys):
        return GeneratedContent(kind: .structure(
          properties: properties.mapValues { $0.generatedContent },
          orderedKeys: orderedKeys
        ))
      }
    }
  }

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  extension ModelOutput: ConvertibleFromGeneratedContent {
    public init(_ content: GeneratedContent) throws {
      let responseID = content.id.map { ResponseID(generationID: $0) }

      switch content.kind {
      case .null:
        self.init(kind: .null, id: responseID)
      case let .bool(value):
        self.init(kind: .bool(value), id: responseID)
      case let .number(value):
        self.init(kind: .number(value), id: responseID)
      case let .string(value):
        self.init(kind: .string(value), id: responseID)
      case let .array(values):
        try self.init(kind: .array(values.map { try ModelOutput($0) }), id: responseID)
      case let .structure(properties: properties, orderedKeys: orderedKeys):
        try self.init(
          kind: .structure(
            properties: properties.mapValues { try ModelOutput($0) }, orderedKeys: orderedKeys
          ),
          id: responseID
        )
      @unknown default:
        assertionFailure("Unknown `FoundationModels.GeneratedContent` kind: \(content.kind)")
        self.init(kind: .null, id: responseID)
      }
    }
  }
#endif // canImport(FoundationModels)
