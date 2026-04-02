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
  import struct FoundationModels.GenerationID
#endif // canImport(FoundationModels)

public extension FirebaseAI {
  /// An identifier for a specific generation.
  ///
  /// **Public Preview**: This API is a public preview and may be subject to change.
  struct GenerationID: Sendable {
    protocol GenerationIDProtocol: Sendable, Hashable {}

    let responseID: String?
    let appleGenerationID: (any GenerationIDProtocol)?

    /// Creates a new, unique generation identifier.
    ///
    /// **Public Preview**: This API is a public preview and may be subject to change.
    public init() {
      responseID = UUID().uuidString
      #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
          appleGenerationID = FoundationModels.GenerationID()
        } else {
          appleGenerationID = nil
        }
      #else
        appleGenerationID = nil
      #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
    }

    init(responseID: String?, generationID: (any GenerationIDProtocol)?) {
      self.responseID = responseID
      appleGenerationID = generationID
    }

    #if canImport(FoundationModels)
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      var generationID: FoundationModels.GenerationID? {
        guard let generationID = appleGenerationID as? FoundationModels.GenerationID else {
          return nil
        }

        return generationID
      }
    #endif // canImport(FoundationModels)
  }
}

#if canImport(FoundationModels)
  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  extension FoundationModels.GenerationID: FirebaseAI.GenerationID.GenerationIDProtocol {}
#endif // canImport(FoundationModels)

extension FirebaseAI.GenerationID: Equatable {
  public static func == (lhs: FirebaseAI.GenerationID, rhs: FirebaseAI.GenerationID) -> Bool {
    guard lhs.responseID == rhs.responseID else {
      return false
    }

    #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
      if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
        guard lhs.generationID == rhs.generationID else {
          return false
        }
      }
    #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM

    return true
  }
}

extension FirebaseAI.GenerationID: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(responseID)

    #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
      if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
        hasher.combine(generationID)
      }
    #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
  }
}
