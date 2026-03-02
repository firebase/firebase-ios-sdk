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
  import FoundationModels
#endif // canImport(FoundationModels)

#if canImport(FoundationModels)
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  extension FoundationModels.GenerationSchema: FirebaseAI.GenerationSchema
    .GenerationSchemaProtocol {}
#endif // canImport(FoundationModels)

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FirebaseAI {
  struct GenerationSchema: Sendable, CustomDebugStringConvertible {
    protocol GenerationSchemaProtocol: Sendable, Codable, CustomDebugStringConvertible {}

    let _generationSchema: (any GenerationSchemaProtocol)?

    #if canImport(FoundationModels)
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      var generationSchema: FoundationModels.GenerationSchema {
        guard let generationSchema = _generationSchema as? FoundationModels.GenerationSchema else {
          assertionFailure("Schema was nil in \(Self.self).#\(#function).")
          // Return generic schema instead in release builds; this should be unreachable.
          return FoundationModels.GeneratedContent.generationSchema
        }

        return generationSchema
      }
    #endif // canImport(FoundationModels)

    public var debugDescription: String {
      #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
          return generationSchema.debugDescription
        }
      #endif // canImport(FoundationModels)

      fatalError("TODO: \(Self.self).#\(#function) not yet implemented for iOS < 26.")
    }

    #if canImport(FoundationModels)
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      public init(_ generationSchema: FoundationModels.GenerationSchema) {
        _generationSchema = generationSchema
      }

      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      public init(type: any FoundationModels.Generable.Type, description: String? = nil,
                  properties: [FoundationModels.GenerationSchema.Property]) {
        _generationSchema = FoundationModels.GenerationSchema(
          type: type,
          description: description,
          properties: properties
        )
      }

      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      public init(type: any FoundationModels.Generable.Type, description: String? = nil,
                  anyOf choices: [String]) {
        _generationSchema = FoundationModels.GenerationSchema(
          type: type,
          description: description,
          anyOf: choices
        )
      }

      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      public init(type: any FoundationModels.Generable.Type, description: String? = nil,
                  anyOf types: [any FoundationModels.Generable.Type]) {
        _generationSchema = FoundationModels.GenerationSchema(
          type: type,
          description: description,
          anyOf: types
        )
      }

      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      public init(root: FoundationModels.DynamicGenerationSchema,
                  dependencies: [FoundationModels.DynamicGenerationSchema]) throws {
        _generationSchema = try FoundationModels.GenerationSchema(
          root: root,
          dependencies: dependencies
        )
      }
    #endif // canImport(FoundationModels)
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension FirebaseAI.GenerationSchema: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()

    #if canImport(FoundationModels)
      if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
        _generationSchema = try container.decode(FoundationModels.GenerationSchema.self)
      }
    #endif

    fatalError("TODO: \(Self.self).#\(#function) not yet implemented for iOS < 26.")
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension FirebaseAI.GenerationSchema: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()

    #if canImport(FoundationModels)
      if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
        try container.encode(generationSchema)
      }
    #endif

    fatalError("TODO: \(Self.self).#\(#function) not yet implemented for iOS < 26.")
  }
}
