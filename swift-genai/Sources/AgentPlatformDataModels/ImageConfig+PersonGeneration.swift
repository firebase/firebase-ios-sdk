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

extension AgentPlatform.ImageConfig {
  /// Optional. Controls whether the model can generate people.
  public enum PersonGeneration: Codable, Sendable, Equatable, Hashable {
    /// Allows the model to generate images of people, including adults and children.
    case all
    
    /// Allows the model to generate images of adults, but not children.
    case adult
    
    /// Prevents the model from generating images of people.
    case none
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension AgentPlatform.ImageConfig.PersonGeneration: RawRepresentable {
  public var rawValue: String {
    switch self {
    case .all: "ALLOW_ALL"
    case .adult: "ALLOW_ADULT"
    case .none: "ALLOW_NONE"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "ALLOW_ALL": self = .all
    case "ALLOW_ADULT": self = .adult
    case "ALLOW_NONE": self = .none
    default: self = .unrecognized(rawValue)
    }
  }
}