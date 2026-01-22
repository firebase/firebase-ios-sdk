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
  internal import struct FoundationModels.GenerationID
#endif // canImport(FoundationModels)

protocol GenerationIDProtocol: Sendable, Hashable {}

#if canImport(FoundationModels)
  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  extension GenerationID: GenerationIDProtocol {}
#endif // canImport(FoundationModels)

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ResponseID: Sendable, Hashable {
  enum Identifier {
    case value(String)
    case generationID(GenerationIDProtocol)
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
    init(generationID: GenerationID) {
      identifier = .generationID(generationID)
    }
  #endif // canImport(FoundationModels)
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ResponseID.Identifier: Equatable {
  static func == (lhs: ResponseID.Identifier, rhs: ResponseID.Identifier) -> Bool {
    if case let .value(lhsValue) = lhs, case let .value(rhsValue) = rhs {
      return lhsValue == rhsValue
    } else if case let .generationID(lhsGenerationID) = lhs,
              case let .generationID(rhsGenerationID) = rhs {
      #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
          guard let lhsGenerationID = lhsGenerationID as? GenerationID,
                let rhsGenerationID = rhsGenerationID as? GenerationID else {
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
extension ResponseID.Identifier: Hashable {
  func hash(into hasher: inout Hasher) {
    switch self {
    case let .value(value):
      hasher.combine(value)
    case let .generationID(generationID):
      hasher.combine(generationID)
    }
  }
}
