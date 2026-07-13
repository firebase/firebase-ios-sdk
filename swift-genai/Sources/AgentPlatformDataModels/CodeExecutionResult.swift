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


extension AgentPlatform {
  /// Result of executing the ExecutableCode. Generated only when the `CodeExecution` tool is used.
  package struct CodeExecutionResult: Codable, Sendable, Equatable, Hashable {
    /// Required. Outcome of the code execution.
    package var outcome: Outcome?
    
    /// Optional. Contains stdout when code execution is successful, stderr or other description otherwise.
    package var output: String?
    
    /// Creates a new `CodeExecutionResult`.
    package init(
      outcome: Outcome? = nil,
      output: String? = nil
    ) {
      self.outcome = outcome
      self.output = output
    }
    enum CodingKeys: String, CodingKey {
      case outcome = "outcome"
      case output = "output"
    }
  }
}