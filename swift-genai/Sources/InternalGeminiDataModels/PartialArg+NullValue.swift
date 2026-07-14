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

extension GeminiDataModels.PartialArg {
  /// Optional. Represents a null value.
  /// 
  /// > Important: `nullValue` is only available in the Gemini Enterprise Agent Platform.
  package enum NullValue: Codable, Sendable, Equatable, Hashable {
    /// Null value.
    case value
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension GeminiDataModels.PartialArg.NullValue: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .value: "NULL_VALUE"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "NULL_VALUE": self = .value
    default: self = .unrecognized(rawValue)
    }
  }
}