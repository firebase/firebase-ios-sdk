// Copyright 2024 Google LLC
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
public struct ImagenSafetySettings {
  let safetyFilterLevel: SafetyFilterLevel?
  let includeFilterReason: Bool?
  let personGeneration: PersonGeneration?

  public init(safetyFilterLevel: SafetyFilterLevel? = nil, includeFilterReason: Bool? = nil,
              personGeneration: PersonGeneration? = nil) {
    self.safetyFilterLevel = safetyFilterLevel
    self.includeFilterReason = includeFilterReason
    self.personGeneration = personGeneration
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension ImagenSafetySettings {
  struct SafetyFilterLevel: ProtoEnum {
    enum Kind: String {
      case blockLowAndAbove = "block_low_and_above"
      case blockMediumAndAbove = "block_medium_and_above"
      case blockOnlyHigh = "block_only_high"
      case blockNone = "block_none"
    }

    public static let blockLowAndAbove = SafetyFilterLevel(kind: .blockLowAndAbove)
    public static let blockMediumAndAbove = SafetyFilterLevel(kind: .blockMediumAndAbove)
    public static let blockOnlyHigh = SafetyFilterLevel(kind: .blockOnlyHigh)
    public static let blockNone = SafetyFilterLevel(kind: .blockNone)

    let rawValue: String
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension ImagenSafetySettings {
  struct PersonGeneration: ProtoEnum {
    enum Kind: String {
      case blockAll = "dont_allow"
      case allowAdult = "allow_adult"
      case allowAll = "allow_all"
    }

    public static let blockAll = PersonGeneration(kind: .blockAll)
    public static let allowAdult = PersonGeneration(kind: .allowAdult)
    public static let allowAll = PersonGeneration(kind: .allowAll)

    let rawValue: String
  }
}
