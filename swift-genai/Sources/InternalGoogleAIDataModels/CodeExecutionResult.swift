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


extension GoogleAI {
  /// Result of executing the `ExecutableCode`. Generated only when the `CodeExecution` tool is used.
  public struct CodeExecutionResult: Codable, Sendable, Equatable, Hashable {
    /// Optional. The identifier of the `ExecutableCode` part this result is for. Only populated if the corresponding `ExecutableCode` has an id.
    public var id: String?
    
    /// Required. Outcome of the code execution.
    public var outcome: Outcome?
    
    /// Optional. Contains stdout when code execution is successful, stderr or other description otherwise.
    public var output: String?
    
    /// Creates a new `CodeExecutionResult`.
    public init(
      id: String? = nil,
      outcome: Outcome? = nil,
      output: String? = nil
    ) {
      self.id = id
      self.outcome = outcome
      self.output = output
    }
    enum CodingKeys: String, CodingKey {
      case id = "id"
      case outcome = "outcome"
      case output = "output"
    }
  }
}