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
  public import protocol FoundationModels.ConvertibleToGeneratedContent
  public import struct FoundationModels.GenerationID
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
    self.id = id
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
    var modelOutput: ModelOutput
    var decodingError: Error?

    // 1. Attempt to decode the JSON with the standard `JSONDecoder` since it likely offers the best
    //    performance and is available on iOS 15+.
    // TODO: Skip this approach when streaming.
    guard let jsonData = json.data(using: .utf8) else {
      fatalError("TODO: Throw a reasonable decoding error")
    }
    do {
      let jsonValue = try JSONDecoder().decode(JSONValue.self, from: jsonData)
      modelOutput = jsonValue.modelOutput
      modelOutput.id = id

      self = modelOutput

      return
    } catch {
      decodingError = error
    }

    // 2. Attempt to decode using `GeneratedContent` from Foundation Models when available. It is
    //    designed to handle streaming JSON.
    #if canImport(FoundationModels)
      if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
        do {
          let generatedContent = try GeneratedContent(json: json)
          modelOutput = generatedContent.modelOutput
          modelOutput.id = id

          self = modelOutput

          return
        } catch {
          decodingError = error
        }
      }
    #endif // canImport(FoundationModels)

    // 3. Fallback to decoding with a custom `StreamingJSONParser` when `GeneratedContent` is not
    //    available.
    let parser = StreamingJSONParser(json)
    if let parsedModelOutput = parser.parse() {
      modelOutput = parsedModelOutput
      modelOutput.id = id

      self = modelOutput

      return
    }

    // 4. Throw a decoding error if all attempts to decode the JSON have failed.
    if let decodingError {
      throw decodingError
    } else {
      fatalError("TODO: Throw a decoding error")
    }
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
      let generationID = id?.generationID

      switch kind {
      case .null:
        return GeneratedContent(kind: .null, id: generationID)
      case let .bool(value):
        return GeneratedContent(kind: .bool(value), id: generationID)
      case let .number(value):
        return GeneratedContent(kind: .number(value), id: generationID)
      case let .string(value):
        return GeneratedContent(kind: .string(value), id: generationID)
      case let .array(values):
        return GeneratedContent(kind: .array(values.map { $0.generatedContent }), id: generationID)
      case let .structure(properties: properties, orderedKeys: orderedKeys):
        return GeneratedContent(
          kind: .structure(
            properties: properties.mapValues { $0.generatedContent }, orderedKeys: orderedKeys
          ),
          id: generationID
        )
      }
    }
  }

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  extension GeneratedContent: ConvertibleToModelOutput {
    public var modelOutput: ModelOutput {
      let responseID = id.map { ResponseID(generationID: $0) }

      switch kind {
      case .null:
        return ModelOutput(kind: .null, id: responseID)
      case let .bool(value):
        return ModelOutput(kind: .bool(value), id: responseID)
      case let .number(value):
        return ModelOutput(kind: .number(value), id: responseID)
      case let .string(value):
        return ModelOutput(kind: .string(value), id: responseID)
      case let .array(values):
        return ModelOutput(kind: .array(values.map { $0.modelOutput }), id: responseID)
      case let .structure(properties: properties, orderedKeys: orderedKeys):
        return ModelOutput(
          kind: .structure(
            properties: properties.mapValues { $0.modelOutput }, orderedKeys: orderedKeys
          ),
          id: responseID
        )
      @unknown default:
        assertionFailure("Unknown `FoundationModels.GeneratedContent` kind: \(kind)")
        return ModelOutput(kind: .null, id: responseID)
      }
    }
  }
#endif // canImport(FoundationModels)
