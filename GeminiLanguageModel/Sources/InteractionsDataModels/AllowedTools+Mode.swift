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

extension AllowedTools {
  /// The mode of the tool choice.
  package enum Mode: Codable, Sendable, Equatable, Hashable {

    /// Auto tool choice.
    case auto

    /// Any tool choice.
    case `any`

    /// No tool choice.
    case none

    /// Validated tool choice.
    case validated

    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension AllowedTools.Mode: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .auto: "auto"
    case .`any`: "any"
    case .none: "none"
    case .validated: "validated"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "auto": self = .auto
    case "any": self = .`any`
    case "none": self = .none
    case "validated": self = .validated
    default: self = .unrecognized(rawValue)
    }
  }
}
