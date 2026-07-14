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

extension GeminiDataModels.ImageConfig {
  /// Optional. Controls whether prominent people (celebrities) generation is allowed. If used with personGeneration, personGeneration enum would take precedence. For instance, if ALLOW_NONE is set, all person generation would be blocked. If this field is unspecified, the default behavior is to allow prominent people.
  /// 
  /// > Important: `prominentPeople` is only available in the Gemini Enterprise Agent Platform.
  package enum ProminentPeople: Codable, Sendable, Equatable, Hashable {
    /// Allows the model to generate images of prominent people.
    case allowProminentPeople
    
    /// Prevents the model from generating images of prominent people.
    case blockProminentPeople
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension GeminiDataModels.ImageConfig.ProminentPeople: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .allowProminentPeople: "ALLOW_PROMINENT_PEOPLE"
    case .blockProminentPeople: "BLOCK_PROMINENT_PEOPLE"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "ALLOW_PROMINENT_PEOPLE": self = .allowProminentPeople
    case "BLOCK_PROMINENT_PEOPLE": self = .blockProminentPeople
    default: self = .unrecognized(rawValue)
    }
  }
}