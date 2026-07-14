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

extension GoogleAI.ExecutableCode {
  /// Required. Programming language of the `code`.
  public enum Language: Codable, Sendable, Equatable, Hashable {
    /// Python >= 3.10, with numpy and simpy available. Python is the default language.
    case python
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension GoogleAI.ExecutableCode.Language: RawRepresentable {
  public var rawValue: String {
    switch self {
    case .python: "PYTHON"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "PYTHON": self = .python
    default: self = .unrecognized(rawValue)
    }
  }
}