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

extension AgentPlatform.EnterpriseWebSearch {
  /// Optional. Sites with confidence level chosen & above this value will be blocked from the search results.
  public enum BlockingConfidence: Codable, Sendable, Equatable, Hashable {
    /// Blocks Low and above confidence URL that is risky.
    case lowAndAbove
    
    /// Blocks Medium and above confidence URL that is risky.
    case mediumAndAbove
    
    /// Blocks High and above confidence URL that is risky.
    case highAndAbove
    
    /// Blocks Higher and above confidence URL that is risky.
    case higherAndAbove
    
    /// Blocks Very high and above confidence URL that is risky.
    case veryHighAndAbove
    
    /// Blocks Extremely high confidence URL that is risky.
    case onlyExtremelyHigh
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension AgentPlatform.EnterpriseWebSearch.BlockingConfidence: RawRepresentable {
  public var rawValue: String {
    switch self {
    case .lowAndAbove: "BLOCK_LOW_AND_ABOVE"
    case .mediumAndAbove: "BLOCK_MEDIUM_AND_ABOVE"
    case .highAndAbove: "BLOCK_HIGH_AND_ABOVE"
    case .higherAndAbove: "BLOCK_HIGHER_AND_ABOVE"
    case .veryHighAndAbove: "BLOCK_VERY_HIGH_AND_ABOVE"
    case .onlyExtremelyHigh: "BLOCK_ONLY_EXTREMELY_HIGH"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "BLOCK_LOW_AND_ABOVE": self = .lowAndAbove
    case "BLOCK_MEDIUM_AND_ABOVE": self = .mediumAndAbove
    case "BLOCK_HIGH_AND_ABOVE": self = .highAndAbove
    case "BLOCK_HIGHER_AND_ABOVE": self = .higherAndAbove
    case "BLOCK_VERY_HIGH_AND_ABOVE": self = .veryHighAndAbove
    case "BLOCK_ONLY_EXTREMELY_HIGH": self = .onlyExtremelyHigh
    default: self = .unrecognized(rawValue)
    }
  }
}