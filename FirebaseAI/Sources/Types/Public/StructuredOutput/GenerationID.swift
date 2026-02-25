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
  struct GenerationID: Sendable, Hashable {
    protocol GenerationIDProtocol: Sendable, Hashable {}

    enum Identifier {
      case value(String)
      case generationID(any GenerationIDProtocol)
    }

    let identifier: Identifier

    public init() {
      identifier = .value(UUID().uuidString)
    }

    init(responseID: String) {
      identifier = .value(responseID)
    }

    #if canImport(FoundationModels)
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      init(generationID: FoundationModels.GenerationID) {
        identifier = .generationID(generationID)
      }

      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      var generationID: FoundationModels.GenerationID? {
        guard case let .generationID(id as FoundationModels.GenerationID) = identifier else {
          return nil
        }

        return id
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
extension FirebaseAI.GenerationID.Identifier: Equatable {
  static func == (lhs: FirebaseAI.GenerationID.Identifier,
                  rhs: FirebaseAI.GenerationID.Identifier) -> Bool {
    if case let .value(lhsValue) = lhs, case let .value(rhsValue) = rhs {
      return lhsValue == rhsValue
    } else if case let .generationID(lhsGenerationID) = lhs,
              case let .generationID(rhsGenerationID) = rhs {
      #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
          guard let lhsGenerationID = lhsGenerationID as? FoundationModels.GenerationID,
                let rhsGenerationID = rhsGenerationID as? FoundationModels.GenerationID else {
            return false
          }

          return lhsGenerationID == rhsGenerationID
        }
      #endif // canImport(FoundationModels)
    }

    return false
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension FirebaseAI.GenerationID.Identifier: Hashable {
  func hash(into hasher: inout Hasher) {
    switch self {
    case let .value(value):
      hasher.combine(value)
    case let .generationID(generationID):
      hasher.combine(generationID)
    }
  }
}
