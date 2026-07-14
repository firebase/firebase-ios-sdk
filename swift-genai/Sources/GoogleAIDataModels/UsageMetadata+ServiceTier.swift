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

extension GoogleAI.UsageMetadata {
  /// Output only. Service tier of the request.
  public enum ServiceTier: Codable, Sendable, Equatable, Hashable {
    /// Default service tier, which is standard.
    case unspecified
    
    /// Standard service tier.
    case standard
    
    /// Flex service tier.
    case flex
    
    /// Priority service tier.
    case priority
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension GoogleAI.UsageMetadata.ServiceTier: RawRepresentable {
  public var rawValue: String {
    switch self {
    case .unspecified: "unspecified"
    case .standard: "standard"
    case .flex: "flex"
    case .priority: "priority"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "unspecified": self = .unspecified
    case "standard": self = .standard
    case "flex": self = .flex
    case "priority": self = .priority
    default: self = .unrecognized(rawValue)
    }
  }
}