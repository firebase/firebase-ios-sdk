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

public extension FirebaseAI {
  struct GenerationSchema: Sendable {
    protocol GenerationSchemaProtocol: Sendable, Codable, CustomDebugStringConvertible {}

    private let _generationSchema: (any GenerationSchemaProtocol)?

    #if canImport(FoundationModels)
      @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
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

      @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      init(_ generationSchema: FoundationModels.GenerationSchema) {
        _generationSchema = generationSchema
      }
    #endif // canImport(FoundationModels)
  }
}

#if canImport(FoundationModels)
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  extension FirebaseAI.GenerationSchema: CustomDebugStringConvertible {
    // TODO: Add CustomDebugStringConvertible conformance for iOS < 26.
    public var debugDescription: String {
      return generationSchema.debugDescription
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  extension FirebaseAI.GenerationSchema: Decodable {
    // TODO: Add Decodable conformance for iOS < 26.
    public init(from decoder: any Decoder) throws {
      let container = try decoder.singleValueContainer()
      _generationSchema = try container.decode(FoundationModels.GenerationSchema.self)
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  extension FirebaseAI.GenerationSchema: Encodable {
    // TODO: Add Encodable conformance for iOS < 26.
    public func encode(to encoder: any Encoder) throws {
      var container = encoder.singleValueContainer()
      try container.encode(generationSchema)
    }
  }
#endif // canImport(FoundationModels)
