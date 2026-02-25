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

#if canImport(FoundationModels)
  import FoundationModels

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public extension FirebaseAI {
    struct GeneratedContent: Sendable, Equatable, CustomDebugStringConvertible {
      let wrapped: FoundationModels.GeneratedContent

      init(json: String) throws {
        wrapped = try FoundationModels.GeneratedContent(json: json)
      }

      // TODO: Replace `GenerationID` with custom type
      init(kind: FoundationModels.GeneratedContent.Kind, id: FoundationModels.GenerationID? = nil) {
        wrapped = FoundationModels.GeneratedContent(kind: kind, id: id)
      }

      public var jsonString: String { wrapped.jsonString }

      // TODO: Replace `ConvertibleFromGeneratedContent` with custom protocol

      public func value<Value>(_ type: Value.Type = Value.self) throws -> Value
        where Value: FoundationModels.ConvertibleFromGeneratedContent {
        return try wrapped.value(type)
      }

      public func value<Value>(_ type: Value.Type = Value.self,
                               forProperty property: String) throws -> Value
        where Value: FoundationModels.ConvertibleFromGeneratedContent {
        return try wrapped.value(type, forProperty: property)
      }

      public func value<Value>(_ type: Value?.Type = Value?.self,
                               forProperty property: String) throws -> Value?
        where Value: FoundationModels.ConvertibleFromGeneratedContent {
        return try wrapped.value(type, forProperty: property)
      }

      public var debugDescription: String { wrapped.debugDescription }

      public var isComplete: Bool { wrapped.isComplete }
    }
  }

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public extension FirebaseAI.GeneratedContent {
    enum Kind: Equatable, Sendable {
      case null
      case bool(Bool)
      case number(Double)
      case string(String)
      case array([FirebaseAI.GeneratedContent])
      case structure(properties: [String: FirebaseAI.GeneratedContent], orderedKeys: [String])
    }

    var kind: FirebaseAI.GeneratedContent.Kind {
      switch wrapped.kind {
      case .null:
        return .null
      case let .bool(value):
        return .bool(value)
      case let .number(value):
        return .number(value)
      case let .string(value):
        return .string(value)
      case let .array(values):
        return .array(values.map { FirebaseAI.GeneratedContent(kind: $0.kind, id: nil) })
      case let .structure(properties, orderedKeys):
        return .structure(
          properties: properties.mapValues { FirebaseAI.GeneratedContent(kind: $0.kind, id: nil) },
          orderedKeys: orderedKeys
        )
      @unknown default:
        assertionFailure("Unknown `FoundationModels.GeneratedContent` kind: \(wrapped.kind)")
        return .null
      }
    }
  }
#endif // canImport(FoundationModels)
