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

extension GeminiDataModels.SafetySetting {
  /// Optional. The method for blocking content. If not specified, the default behavior is to use the probability score.
  /// 
  /// > Important: `method` is only available in the Gemini Enterprise Agent Platform.
  package enum Method: Codable, Sendable, Equatable, Hashable {
    /// The harm block method uses both probability and severity scores.
    case severity
    
    /// The harm block method uses the probability score.
    case probability
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension GeminiDataModels.SafetySetting.Method: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .severity: "SEVERITY"
    case .probability: "PROBABILITY"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "SEVERITY": self = .severity
    case "PROBABILITY": self = .probability
    default: self = .unrecognized(rawValue)
    }
  }
}