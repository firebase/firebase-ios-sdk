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

extension GoogleAI.CodeExecutionResult {
  /// Required. Outcome of the code execution.
  package enum Outcome: Codable, Sendable, Equatable, Hashable {
    /// Code execution completed successfully. `output` contains the stdout, if any.
    case ok
    
    /// Code execution failed. `output` contains the stderr and stdout, if any.
    case failed
    
    /// Code execution ran for too long, and was cancelled. There may or may not be a partial `output` present.
    case deadlineExceeded
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension GoogleAI.CodeExecutionResult.Outcome: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .ok: "OUTCOME_OK"
    case .failed: "OUTCOME_FAILED"
    case .deadlineExceeded: "OUTCOME_DEADLINE_EXCEEDED"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "OUTCOME_OK": self = .ok
    case "OUTCOME_FAILED": self = .failed
    case "OUTCOME_DEADLINE_EXCEEDED": self = .deadlineExceeded
    default: self = .unrecognized(rawValue)
    }
  }
}