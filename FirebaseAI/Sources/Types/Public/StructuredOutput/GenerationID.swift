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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FirebaseAI {
  struct GenerationID: Sendable {
    protocol GenerationIDProtocol: Sendable, Hashable {}

    let responseID: String
    let appleGenerationID: GenerationIDProtocol?

    public init() {
      responseID = UUID().uuidString
      let appleGenerationID: GenerationIDProtocol?
      #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
          appleGenerationID = FoundationModels.GenerationID()
        } else {
          appleGenerationID = nil
        }
      #else
        appleGenerationID = nil
      #endif // canImport(FoundationModels)
      self.appleGenerationID = appleGenerationID
    }

    init(responseID: String, generationID: GenerationIDProtocol?) {
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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension FirebaseAI.GenerationID: Equatable {
  public static func == (lhs: FirebaseAI.GenerationID, rhs: FirebaseAI.GenerationID) -> Bool {
    guard lhs.responseID == rhs.responseID else {
      return false
    }

    #if canImport(FoundationModels)
      if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
        guard lhs.generationID == rhs.generationID else {
          return false
        }
      }
    #endif // canImport(FoundationModels)

    return true
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension FirebaseAI.GenerationID: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(responseID)

    #if canImport(FoundationModels)
      if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
        hasher.combine(generationID)
      }
    #endif // canImport(FoundationModels)
  }
}
